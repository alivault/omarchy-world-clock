import QtQuick
import qs.Commons

Item {
  id: root
  required property var editor
  required property Item listView
  required property int rowIndex
  required property string label
  activeFocusOnTab: true
  enabled: !editor.saving
  Accessible.role: Accessible.Button
  Accessible.name: "Reorder " + label
  Accessible.description: "Drag, or use Up and Down arrows to reorder"
  Keys.onUpPressed: editor.moveCity(rowIndex, rowIndex - 1, true)
  Keys.onDownPressed: editor.moveCity(rowIndex, rowIndex + 1, true)

  Column {
    anchors.centerIn: parent
    spacing: Style.space(3)
    opacity: 0.45
    Repeater {
      model: 3
      Rectangle {
        width: Style.space(18)
        height: Style.space(1)
        radius: height / 2
        color: Color.foreground
      }
    }
  }
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    acceptedButtons: Qt.LeftButton
    property real pressY: 0
    onPressed: function(mouse) {
      root.forceActiveFocus()
      pressY = mapToItem(root.listView, mouse.x, mouse.y).y
    }
    onPositionChanged: function(mouse) {
      if (!pressed) return
      var pointerY = mapToItem(root.listView, mouse.x, mouse.y).y
      if (!root.editor.dragging) {
        if (Math.abs(pointerY - pressY) < Style.space(4)) return
        root.editor.dragFrom = root.rowIndex
      }
      root.editor.dragY = pointerY
      root.editor.updateDrop()
    }
    onReleased: function(mouse) {
      if (!root.editor.dragging) return
      var point = mapToItem(root.listView, mouse.x, mouse.y)
      root.editor.finishDrag(point.x >= 0 && point.x <= root.listView.rowWidth
        && point.y >= 0 && point.y <= root.listView.height)
    }
    onCanceled: root.editor.finishDrag(false)
  }
}
