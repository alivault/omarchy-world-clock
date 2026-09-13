import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

FocusScope {
  id: root
  property string fontFamily: Style.font.family
  property bool editing: false
  property bool adding: false
  property bool busy: false
  signal editRequested()
  signal addRequested()
  signal doneRequested()
  signal backRequested()
  signal dismissRequested()
  implicitHeight: content.implicitHeight

  function focusPrimary() { primary.forceActiveFocus() }
  Keys.onEscapePressed: root.dismissRequested()

  Column {
    id: content
    width: parent.width
    spacing: Style.space(12)
    RowLayout {
      width: parent.width
      height: Style.space(36)
      spacing: Style.space(10)
      Ui.Button {
        visible: root.adding
        text: "‹ Back"
        fontFamily: root.fontFamily
        focusable: true
        borderSpec: Border.none()
        color: hot || activeFocus ? Qt.alpha(foreground, 0.08) : "transparent"
        enabled: !root.busy
        onClicked: root.backRequested()
      }
      Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: root.adding ? "Add City" : "World Clock"
        color: Color.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.space(28)
        font.bold: true
        textFormat: Text.PlainText
        elide: Text.ElideRight
      }
      Ui.Button {
        id: primary
        visible: !root.adding
        Layout.preferredWidth: Style.space(root.editing ? 36 : 54)
        Layout.preferredHeight: Style.space(36)
        text: root.busy ? "…" : root.editing ? "✓" : "Edit"
        fontFamily: root.fontFamily
        fontSize: Style.space(root.editing ? 22 : 13)
        foreground: root.editing ? Color.background : Color.foreground
        color: root.editing ? Color.accent : Qt.alpha(Color.foreground, hot || activeFocus ? 0.14 : 0.07)
        borderSpec: Border.none()
        radius: height / 2
        focusable: true
        enabled: !root.busy
        Accessible.name: root.editing ? "Save cities" : "Edit cities"
        onClicked: root.editing ? root.doneRequested() : root.editRequested()
      }
      Ui.Button {
        visible: !root.adding
        Layout.preferredWidth: Style.space(36)
        Layout.preferredHeight: Style.space(36)
        text: "+"
        fontFamily: root.fontFamily
        fontSize: Style.space(26)
        color: Qt.alpha(foreground, hot || activeFocus ? 0.14 : 0.07)
        borderSpec: Border.none()
        radius: height / 2
        focusable: true
        enabled: !root.busy
        Accessible.name: "Add city"
        onClicked: root.addRequested()
      }
    }
    Rectangle {
      width: parent.width
      height: 1
      color: Color.foreground
      opacity: 0.14
    }
  }
}
