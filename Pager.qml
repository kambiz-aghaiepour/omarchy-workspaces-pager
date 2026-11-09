import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// KDE-style desktop pager: a rows x columns grid of boxes, one per virtual
// desktop, the active one outlined in the accent color. Click a box to focus
// that desktop; right-click anywhere on the widget opens the control panel
// (rows, workspace count, navigation toggles).
//
// Settings live on this widget's entry in shell.json (edited by the panel):
//   rows     - 1 or 2; the grid wraps left-to-right, top-to-bottom, so 8
//              workspaces in 2 rows render as two rows of four and 5
//              workspaces as three on top, two below
//   desktops - how many virtual desktops the pager shows
//   keybinds - gate for the Ctrl+Alt+arrow navigation helper
//   gestures - gate for the three-finger swipe navigation helper
BarWidget {
  id: root
  moduleName: "io.github.kambiz.workspaces-pager"

  readonly property int rows: {
    var v = parseInt(settings && settings.rows, 10)
    return v === 1 ? 1 : 2
  }
  readonly property int desktops: {
    var v = parseInt(settings && settings.desktops, 10)
    return v >= 1 && v <= 20 ? v : 8
  }
  readonly property int columns: Math.ceil(desktops / rows)

  readonly property int activeId: {
    var ws = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace : null
    return ws ? ws.id : -1
  }

  function focusWorkspace(id) {
    Hyprland.dispatch("workspace " + id)
  }

  // ---- Settings persistence (same wiring as Omarchy's clock).

  function saveSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (panelLoader.item && "settings" in panelLoader.item) panelLoader.item.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // ---- Control panel (Panel.qml), opened with a right-click.

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true : false

  function openPanel() { if (panelLoader.item) panelLoader.item.open() }
  function closePanel() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = root
    target.hostWidget = root
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  // One cell per desktop; landscape aspect like the KDE pager, height bound
  // by the bar and split across rows.
  component Cell: Rectangle {
    id: cell

    required property int index
    readonly property int desktopId: index + 1
    readonly property bool active: root.activeId === desktopId

    Layout.preferredWidth: root.barSize * 1.15 / (root.rows === 2 ? 1.45 : 1)
    Layout.preferredHeight: (root.barSize - 6) / root.rows
    radius: 3
    color: active ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28)
                  : Qt.rgba(1, 1, 1, 0.10)
    border.width: active ? 2 : 1
    border.color: active ? Color.accent : Qt.rgba(1, 1, 1, 0.16)

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.togglePanel()
        else root.focusWorkspace(parent.desktopId)
      }
    }
  }

  GridLayout {
    id: grid
    anchors.centerIn: parent
    columns: root.columns
    rows: root.rows
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

  // Remote control: omarchy-shell io.github.kambiz.workspaces-pager <method> [arg]
  ShellIpc {
    target: "io.github.kambiz.workspaces-pager"
    function open(): void { root.openPanel() }
    function close(): void { root.closePanel() }
    function toggle(): void { root.togglePanel() }
    function applySettings(json: string): void { root.saveSettings(JSON.parse(json)) }
    function panelStatus(): string {
      var p = panelLoader.item
      return p && "status" in p ? p.status() : "no-panel"
    }
  }
}
