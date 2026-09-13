import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui

Item {
  id: root
  required property var initialZones
  required property var choices
  required property string scriptPath
  property string hourFormat: "12h"
  property bool startAdding: false
  property bool adding: startAdding
  property string fontFamily: Style.font.family
  property bool saving: false
  property string errorText: ""
  property var draft: []
  readonly property real cityRowHeight: Style.space(76)
  property real editScrollOffset: 0
  property var details: ({})
  property var requestedZones: []
  property bool detailRefreshPending: false
  property string detailError: ""
  implicitHeight: header.implicitHeight + Style.space(10)
    + (adding ? Style.space(350) : Math.max(1, draft.length) * cityRowHeight)
    + (errorText || detailError ? Style.space(42) : 0)
  property int dragFrom: -1
  property int dropIndex: -1
  property real dragY: 0
  readonly property bool dragging: dragFrom >= 0
  readonly property var results: {
    var query = search.text.trim().toLowerCase().replace(/_/g, " ")
    return choices.filter(function(city) {
      return (city.label + " " + city.zone.replace(/_/g, " ")).toLowerCase().indexOf(query) !== -1
    })
  }
  signal saveRequested(var cities)
  signal cancelRequested()

  function focusInitial() {
    Qt.callLater(function() {
      if (root.adding) search.forceActiveFocus()
      else header.focusPrimary()
    })
  }
  function showSearch() {
    if (saving || dragging) return
    editScrollOffset = selected.contentY - selected.originY
    adding = true
    search.text = ""
    focusInitial()
  }
  function backToEditor() {
    adding = false
    Qt.callLater(function() { restoreScrollOffset(editScrollOffset); header.focusPrimary() })
  }
  function cityKey(city) { return JSON.stringify([city.zone, city.label]) }
  function refreshDetails() {
    if (detailReader.running) { detailRefreshPending = true; return }
    requestedZones = draft.slice()
    detailReader.command = ["python3", scriptPath, JSON.stringify(requestedZones), hourFormat]
    detailReader.running = true
  }
  onDraftChanged: Qt.callLater(refreshDetails)
  onHourFormatChanged: Qt.callLater(refreshDetails)
  function includes(city) {
    return draft.some(function(entry) { return entry.zone === city.zone && entry.label === city.label })
  }
  function add(city) {
    if (saving || includes(city)) return
    draft = draft.concat([{ label: city.label, zone: city.zone }])
    adding = false
    Qt.callLater(function() {
      selected.forceLayout()
      selected.positionViewAtEnd()
      header.focusPrimary()
    })
  }
  function remove(index) {
    if (saving || dragging || index < 0 || index >= draft.length) return
    var scrollOffset = selected.contentY - selected.originY
    // Keep the same visible rows when deleting an entry above the viewport.
    if ((index + 1) * cityRowHeight <= scrollOffset) scrollOffset -= cityRowHeight
    var next = draft.slice()
    next.splice(index, 1)
    draft = next
    Qt.callLater(function() { restoreScrollOffset(scrollOffset) })
  }
  function restoreScrollOffset(offset) {
    selected.forceLayout()
    selected.contentY = selected.originY + Math.max(0,
      Math.min(offset, selected.contentHeight - selected.height))
  }
  function moveCity(from, to, keyboard) {
    if (saving || dragging || from < 0 || to < 0 || from >= draft.length || to >= draft.length || from === to) return
    var scrollOffset = selected.contentY - selected.originY
    var next = draft.slice()
    next.splice(to, 0, next.splice(from, 1)[0])
    draft = next
    if (keyboard) Qt.callLater(function() {
      selected.currentIndex = to
      selected.positionViewAtIndex(to, ListView.Contain)
      if (selected.currentItem) selected.currentItem.focusHandle()
    })
    else Qt.callLater(function() { restoreScrollOffset(scrollOffset) })
  }
  function updateDrop() {
    if (!dragging) return
    dropIndex = Math.max(0, Math.min(draft.length - 1,
      Math.floor((dragY + selected.contentY - selected.originY) / cityRowHeight)))
  }
  function finishDrag(commit) {
    var from = dragFrom
    var to = dropIndex
    dragFrom = -1
    dropIndex = -1
    if (commit) moveCity(from, to, false)
  }
  Component.onCompleted: draft = initialZones.map(function(city) {
    return { label: String(city.label || city.zone || "Home"), zone: String(city.zone || "") }
  })
  Keys.onEscapePressed: {
    if (dragging) finishDrag(false)
    else if (!saving && adding) backToEditor()
    else if (!saving) cancelRequested()
  }

  SystemClock {
    precision: SystemClock.Minutes
    onDateChanged: root.refreshDetails()
  }
  Process {
    id: detailReader
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var rows = JSON.parse(text)
          if (!Array.isArray(rows) || rows.length !== root.requestedZones.length) throw new Error("Invalid clock data")
          var next = Object.assign({}, root.details)
          for (var i = 0; i < rows.length; i++) next[root.cityKey(root.requestedZones[i])] = rows[i].detail
          root.details = next
          root.detailError = ""
        } catch (error) { root.detailError = "Could not refresh time labels." }
      }
    }
    onExited: function(code, status) {
      if (code !== 0 || status !== 0) root.detailError = "Could not refresh time labels."
      if (root.detailRefreshPending) {
        root.detailRefreshPending = false
        Qt.callLater(root.refreshDetails)
      }
    }
  }

  Timer {
    interval: 40
    repeat: true
    running: root.dragging
    onTriggered: {
      var edge = root.cityRowHeight * 0.7
      var direction = root.dragY < edge ? -1 : root.dragY > selected.height - edge ? 1 : 0
      if (!direction) return
      var minY = selected.originY
      var maxY = minY + Math.max(0, selected.contentHeight - selected.height)
      selected.contentY = Math.max(minY, Math.min(maxY, selected.contentY + direction * Style.space(8)))
      root.updateDrop()
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(10)

    ClockHeader {
      id: header
      Layout.fillWidth: true
      fontFamily: root.fontFamily
      editing: true
      adding: root.adding
      busy: root.saving || root.dragging
      onAddRequested: root.showSearch()
      onDoneRequested: root.saveRequested(root.draft)
      onBackRequested: root.backToEditor()
      onDismissRequested: {
        if (root.dragging) root.finishDrag(false)
        else if (!root.saving && root.adding) root.backToEditor()
        else if (!root.saving) root.cancelRequested()
      }
    }

    ListView {
      id: selected
      readonly property real rowWidth: Math.max(0, width - selectedScroll.width - Style.space(6))
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: !root.adding
      model: root.draft
      clip: true
      interactive: !root.dragging
      // Keep the pressed handle alive while auto-scrolling a long list.
      cacheBuffer: root.dragging ? contentHeight : root.cityRowHeight * 2
      onContentYChanged: root.updateDrop()
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar {
        id: selectedScroll
        policy: ScrollBar.AsNeeded
      }
      Text {
        anchors.centerIn: parent
        visible: !root.draft.length
        text: "Use + to add a city"
        color: Color.foreground
        opacity: 0.55
        font.family: root.fontFamily
        font.pixelSize: Style.space(12)
      }
      delegate: Item {
        id: cityRow
        required property var modelData
        required property int index
        width: selected.rowWidth
        height: root.cityRowHeight
        function focusHandle() { handle.forceActiveFocus() }

        RowLayout {
          anchors.fill: parent
          spacing: Style.space(14)
          opacity: root.dragFrom === cityRow.index ? 0.3 : 1
          Ui.Button {
            Layout.preferredWidth: Style.space(24)
            Layout.preferredHeight: Style.space(24)
            Layout.fillWidth: false
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignVCenter
            text: "−"
            fontSize: Style.space(20)
            foreground: "white"
            color: hot || activeFocus ? "#ff666b" : "#ff3b45"
            radius: width / 2
            borderSpec: Border.none()
            focusable: true
            enabled: !root.saving && !root.dragging
            Accessible.name: "Remove " + cityRow.modelData.label
            onClicked: root.remove(cityRow.index)
          }
          Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Style.space(4)
            Text {
              width: parent.width
              text: root.details[root.cityKey(cityRow.modelData)] || "Reading time…"
              color: Color.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.space(12)
              textFormat: Text.PlainText
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: cityRow.modelData.label
              color: Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.space(24)
              textFormat: Text.PlainText
              elide: Text.ElideRight
            }
          }
          ReorderGrip {
            id: handle
            Layout.preferredWidth: Style.space(28)
            Layout.fillHeight: true
            editor: root
            listView: selected
            rowIndex: cityRow.index
            label: cityRow.modelData.label
          }
        }

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 1
          color: Color.foreground
          opacity: 0.14
        }
        Rectangle {
          width: parent.width
          height: Style.space(2)
          y: root.dropIndex > root.dragFrom ? parent.height - height : 0
          color: Color.accent
          visible: root.dragging && root.dropIndex !== root.dragFrom && root.dropIndex === cityRow.index
        }
      }
    }

    Ui.TextField {
      id: search
      Layout.fillWidth: true
      visible: root.adding
      placeholderText: "Add city — search city or timezone…"
      font.family: root.fontFamily
      enabled: !root.saving
      onTextChanged: matches.currentIndex = 0
      onAccepted: if (root.results.length) root.add(root.results[Math.max(0, matches.currentIndex)])
      Keys.onDownPressed: matches.currentIndex = Math.min(root.results.length - 1, matches.currentIndex + 1)
      Keys.onUpPressed: matches.currentIndex = Math.max(0, matches.currentIndex - 1)
    }

    ListView {
      id: matches
      readonly property real rowWidth: Math.max(0, width - matchesScroll.width - Style.space(6))
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: root.adding
      model: root.results
      currentIndex: 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar {
        id: matchesScroll
        policy: ScrollBar.AsNeeded
      }
      Text {
        anchors.centerIn: parent
        visible: !root.results.length
        text: "No matching timezone"
        color: Color.foreground
        opacity: 0.55
        font.family: root.fontFamily
        font.pixelSize: Style.space(12)
      }
      delegate: Item {
        id: result
        required property var modelData
        required property int index
        width: matches.rowWidth
        height: Style.space(46)
        readonly property bool added: root.includes(modelData)
        Ui.Button {
          anchors.fill: parent
          focusable: true
          enabled: !root.saving && !result.added
          hasCursor: matches.currentIndex === result.index && search.activeFocus
          tooltipText: result.added ? "Already added" : "Add " + result.modelData.label
          onClicked: root.add(result.modelData)
          Accessible.name: "Add " + result.modelData.label + ", " + result.modelData.zone
        }
        Column {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.right: mark.left
          anchors.verticalCenter: parent.verticalCenter
          Text {
            width: parent.width
            text: result.modelData.label
            color: Color.foreground
            opacity: result.added ? 0.45 : 1
            font.family: root.fontFamily
            font.pixelSize: Style.space(13)
            textFormat: Text.PlainText
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: result.modelData.zone || "System timezone"
            color: Color.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.space(10)
            textFormat: Text.PlainText
            elide: Text.ElideRight
          }
        }
        Text {
          id: mark
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: result.added ? "✓" : "+"
          color: Color.foreground
          opacity: result.added ? 0.45 : 1
          font.family: root.fontFamily
          font.pixelSize: Style.space(18)
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: root.errorText !== "" || root.detailError !== ""
      text: root.errorText || root.detailError
      color: Color.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.space(12)
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
    }

  }

  Rectangle {
    // Floating row follows the pointer without mutating the model mid-drag.
    readonly property point position: selected.mapToItem(root, 0,
      Math.max(0, Math.min(selected.height - root.cityRowHeight, root.dragY - root.cityRowHeight / 2)))
    x: position.x
    y: position.y
    width: selected.rowWidth
    height: root.cityRowHeight
    visible: root.dragging
    z: 10
    radius: Style.cornerRadius
    color: Color.popups.background
    border.color: Qt.alpha(Color.foreground, 0.45)
    border.width: 1
    opacity: 0.92
    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      verticalAlignment: Text.AlignVCenter
      text: root.dragging && root.draft[root.dragFrom] ? "⠿  " + root.draft[root.dragFrom].label : ""
      color: Color.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.space(14)
      textFormat: Text.PlainText
      elide: Text.ElideRight
    }
  }
}
