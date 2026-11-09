import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// KDE-style desktop pager: a rows x columns grid of boxes, one per virtual
// desktop, the active one outlined in the accent color. Click a box to focus
// that desktop; right-click toggles 1/2 rows (persisted for the session).
//
// Configuration lives in the bar entry's settings (shell.json):
//   { "id": "pager", "settings": { "rows": 2, "desktops": 8 } }
//   rows     - 1 or 2; the grid wraps left-to-right, top-to-bottom, so 8
//              desktops in 2 rows render as two rows of four
//   desktops - how many virtual desktops the pager shows (omarchy default
//              pool is 10 per monitor; set this to the ones you actually use)
BarWidget {
  id: root
  moduleName: "pager"

  readonly property int rows: {
    var v = parseInt(settings && settings.rows, 10)
    return v === 1 ? 1 : 2
  }
  readonly property int desktops: {
    var v = parseInt(settings && settings.desktops, 10)
    return v >= 1 && v <= 20 ? v : 8
  }
  readonly property int columns: Math.ceil(desktops / rows)

  // Persisted across shell reload; right-click toggles rows 1 <-> 2.
  PersistentProperties {
    id: persisted
    reloadableId: "pager-rows"
    property int savedRows: 0
  }

  readonly property int effectiveRows: persisted.savedRows > 0 ? persisted.savedRows : root.rows
  readonly property int effectiveColumns: Math.ceil(root.desktops / effectiveRows)

    readonly property int activeId: {
    var ws = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace : null
    return ws ? ws.id : -1
  }

  function focusWorkspace(id) {
    Hyprland.dispatch("workspace " + id)
  }

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

    // One cell per desktop; landscape aspect like the KDE pager, height bound
  // by the bar and split across rows.
  component Cell: Rectangle {
    id: cell

    required property int index
    readonly property int desktopId: index + 1
    readonly property bool active: root.activeId === desktopId

    Layout.preferredWidth: root.barSize * 1.15 / (root.effectiveRows === 2 ? 1.45 : 1)
    Layout.preferredHeight: (root.barSize - 6) / root.effectiveRows
    radius: 3
    color: active ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                  : Qt.rgba(1, 1, 1, 0.10)
    border.width: active ? 2 : 1
    border.color: active ? Color.accent : Qt.rgba(1, 1, 1, 0.16)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          persisted.savedRows = root.effectiveRows === 2 ? 1 : 2
        } else {
          root.focusWorkspace(parent.desktopId)
        }
      }
    }
  }

  GridLayout {
    id: grid
    anchors.centerIn: parent
    columns: root.effectiveColumns
    rows: root.effectiveRows
    columnSpacing: 3
    rowSpacing: 2

    Repeater {
      model: root.desktops
      Cell {}
    }
  }

  // Keep the highlight exact: the focused monitor's workspace is the truth,
  // and switch events must trigger a re-read of every monitor's state.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "workspacev2" || name === "fullscreen") Hyprland.refreshMonitors()
    }
  }
}
