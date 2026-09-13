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
  property string panelMode: "clocks"
  property var catalog: null
  property string editorError: ""
  property var pendingZones: []
  property string saveReply: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  component GhostMenuButton: Ui.Button {
    borderSpec: Border.none()
    color: hot || activeFocus ? Qt.alpha(foreground, 0.08) : "transparent"
    fontSize: Style.font.bodySmall
    // Ui.Button reserves a focus border even when our ghost border is hidden.
    leftPadding: Style.space(28) - _reservedBorderLeft
  }

  function open() {
    panelMode = "clocks"
    popup.controller.show()
    refresh()
  }
  function close() { popup.close() }
  function closeForPopoutSwitch() { popup.closeForPopoutSwitch() }
  function toggle() { opened ? close() : open() }
  function showMenu() {
    if (opened && panelMode === "menu") { close(); return }
    panelMode = "menu"
    popup.controller.show()
    Qt.callLater(function() { editButton.forceActiveFocus() })
  }
  function editCities() {
    editorError = ""
    panelMode = "edit"
    if (!catalog && !catalogReader.running) catalogReader.running = true
    Qt.callLater(function() { if (editor.item) editor.item.focusSearch() })
  }
  function saveCities(cities) {
    if (saver.running) return
    editorError = ""
    saveReply = ""
    pendingZones = cities.slice()
    // Quickshell's CLI expands a bare [...] argument into multiple arguments.
    // Leading JSON whitespace prevents that expansion without changing data.
    // Use the same settings IPC as `omarchy bar set`, with separate argv entries.
    saver.command = ["omarchy-shell", "shell", "setBarWidget", root.moduleName,
      "zones", " " + JSON.stringify(pendingZones), "{}"]
    saver.running = true
  }
  function toggleHourFormat() {
    if (!bar) return
    var nextFormat = hourFormat === "24h" ? "12h" : "24h"
    bar.run("omarchy bar set ali.world-clock hourFormat " + nextFormat)
    open()
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
    id: catalogReader
    command: ["python3", root.scriptPath, "--catalog"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (!Array.isArray(data.choices) || !Array.isArray(data.defaults)) throw new Error("Invalid catalog")
          root.catalog = data
        } catch (error) { root.editorError = "Could not load timezones. Close and try again." }
      }
    }
    onExited: function(code, status) {
      if (code !== 0 || status !== 0) root.editorError = "Could not load timezones. Check Python and tzdata."
    }
  }

  Process {
    id: saver
    stdout: StdioCollector { onStreamFinished: root.saveReply = text.trim() }
    onExited: function(code, status) {
      if (code !== 0 || status !== 0 || root.saveReply !== "ok") {
        root.editorError = "Could not save cities. Your saved list is unchanged; try again."
        return
      }
      var updated = Object.assign({}, root.settings)
      updated.zones = root.pendingZones
      root.settings = updated
      if (root.opened) root.open()
    }
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
    tooltipText: "World Clock"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.showMenu()
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
    padding: Style.space(root.panelMode === "menu" ? 8 : 16)
    // Match tray-app dropdowns (Mektubi, Bitwarden), not the accent panel frame.
    borderSpec: root.panelMode === "menu"
      ? Border.localOrSurfaceSpec("popups", "border",
          Qt.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.45),
          Color.popups.border, Math.max(1, Style.space(2)))
      : Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    contentWidth: fittedContentWidth(Style.space(root.panelMode === "menu" ? 232 : 390))
    contentHeight: fittedContentHeight(root.panelMode === "menu" ? menu.implicitHeight
      : root.panelMode === "edit" ? Style.space(500)
      : root.clocks.length > 0 && !root.errorText ? root.clocks.length * root.rowHeight : Style.space(76))
    focusTarget: keys

    Ui.PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: root.panelMode !== "clocks"
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + dy * root.rowHeight))
      }

      Column {
        id: menu
        width: parent.width
        spacing: 0
        visible: root.panelMode === "menu"
        Keys.onEscapePressed: root.close()
        GhostMenuButton {
          id: editButton
          width: parent.width
          height: Style.space(30)
          leftAlign: true
          focusable: true
          text: "Edit cities…"
          onClicked: root.editCities()
          Keys.onDownPressed: formatButton.forceActiveFocus()
        }
        GhostMenuButton {
          id: formatButton
          width: parent.width
          height: Style.space(30)
          leftAlign: true
          focusable: true
          text: root.hourFormat === "24h" ? "Use 12-hour time" : "Use 24-hour time"
          onClicked: root.toggleHourFormat()
          Keys.onUpPressed: editButton.forceActiveFocus()
        }
      }

      Loader {
        id: editor
        anchors.fill: parent
        active: root.opened && root.panelMode === "edit" && root.catalog !== null
        visible: active
        sourceComponent: CityEditor {
          initialZones: root.zones === null ? root.catalog.defaults : root.zones
          choices: root.catalog.choices
          saving: saver.running
          errorText: root.editorError
          fontFamily: root.uiFont
          onSaveRequested: function(cities) { root.saveCities(cities) }
          onCancelRequested: root.open()
        }
        onLoaded: item.focusSearch()
      }

      Text {
        anchors.fill: parent
        visible: root.panelMode === "edit" && !editor.active
        text: root.editorError || "Loading timezones…"
        color: root.foreground
        font.family: root.uiFont
        font.pixelSize: Style.space(14)
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
      }

      Text {
        anchors.fill: parent
        visible: root.panelMode === "clocks" && (root.errorText !== "" || root.clocks.length === 0)
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
        visible: root.panelMode === "clocks" && root.errorText === ""
        model: root.clocks
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
        }

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
