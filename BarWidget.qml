import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui

Ui.BarWidget {
  id: root
  moduleName: "ali.world-clock"

  readonly property bool opened: popup.opened
  readonly property bool popoutSwitchClosing: popup.popoutSwitchClosing
  readonly property var zones: setting("zones", null)
  readonly property string hourFormat: String(setting("hourFormat", "12h"))
  readonly property string uiFont: String(setting("fontFamily", bar ? bar.fontFamily : Style.font.family))
  readonly property real rowHeight: Style.space(76)
  readonly property color foreground: Color.foreground
  readonly property string scriptPath: decodeURIComponent(String(Qt.resolvedUrl("clock.py")).replace(/^file:\/\//, ""))
  property var clocks: []
  property string errorText: ""
  property bool refreshPending: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    popup.controller.show()
    refresh()
  }
  function close() { popup.close() }
  function closeForPopoutSwitch() { popup.closeForPopoutSwitch() }
  function toggle() { opened ? close() : open() }
  function toggleHourFormat() {
    if (!bar) return
    var nextFormat = hourFormat === "24h" ? "12h" : "24h"
    bar.run("omarchy bar set ali.world-clock hourFormat " + nextFormat)
  }
  function switchPanel(direction) {
    return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(root, direction) : false
  }
  function refresh() {
    if (reader.running) {
      refreshPending = true
      return
    }
    reader.command = ["python3", root.scriptPath, JSON.stringify(root.zones), root.hourFormat]
    reader.running = true
  }

  onZonesChanged: if (opened) refresh()
  onHourFormatChanged: if (opened) refresh()

  SystemClock {
    precision: SystemClock.Minutes
    onDateChanged: if (root.opened) root.refresh()
  }

  Process {
    id: reader
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var rows = JSON.parse(text)
          if (!Array.isArray(rows)) throw new Error("Invalid clock data")
          root.clocks = rows
          root.errorText = ""
        } catch (error) {
          root.errorText = "Could not read clocks. Click the globe to retry."
        }
      }
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0)
        root.errorText = "Could not read clocks. Check Python and timezone settings."
      if (root.refreshPending) {
        root.refreshPending = false
        Qt.callLater(root.refresh)
      }
    }
  }

  Ui.WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱉊"
    tooltipText: "Omarchy World Clock · Right-click for 12/24-hour time"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleHourFormat()
      else if (mouseButton === Qt.LeftButton) root.toggle()
    }
  }

  Ui.Panel {
    id: popup
    moduleName: root.moduleName
    bar: root.bar
    manageIpc: false
  }

  Ui.KeyboardPanel {
    id: card
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    padding: Style.space(16)
    contentWidth: fittedContentWidth(Style.space(390))
    contentHeight: fittedContentHeight(root.clocks.length > 0 && !root.errorText
      ? root.clocks.length * root.rowHeight : Style.space(76))
    focusTarget: keys

    Ui.PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + dy * root.rowHeight))
      }

      Text {
        anchors.fill: parent
        visible: root.errorText !== "" || root.clocks.length === 0
        text: root.errorText || (reader.running ? "Reading clocks…" : "No cities configured")
        color: root.foreground
        font.family: root.uiFont
        font.pixelSize: Style.space(14)
        wrapMode: Text.WordWrap
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
      }

      ListView {
        id: list
        anchors.fill: parent
        visible: root.errorText === ""
        model: root.clocks
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
          id: row
          required property var modelData
          required property int index
          width: list.width
          height: root.rowHeight

          Column {
            anchors.left: parent.left
            anchors.right: timeGroup.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Text {
              width: parent.width
              text: row.modelData.detail
              color: root.foreground
              opacity: 0.5
              font.family: root.uiFont
              font.pixelSize: Style.space(12)
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
            Text {
              width: parent.width
              text: row.modelData.label
              color: root.foreground
              font.family: root.uiFont
              font.pixelSize: Style.space(21)
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
          }

          Row {
            id: timeGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              id: digits
              text: row.modelData.time
              color: root.foreground
              font.family: root.uiFont
              font.pixelSize: Style.space(46)
              font.weight: Font.Light
              textFormat: Text.PlainText
            }
            Text {
              anchors.baseline: digits.baseline
              visible: text !== ""
              text: row.modelData.period
              color: root.foreground
              font.family: root.uiFont
              font.pixelSize: Style.space(20)
              font.weight: Font.Light
              textFormat: Text.PlainText
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.foreground
            opacity: 0.12
            visible: row.index < root.clocks.length - 1
          }
        }
      }
    }
  }
}
