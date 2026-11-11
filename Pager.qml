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
//   clickNavigation - allow left-clicking a box to focus that workspace
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
  readonly property bool clickNavigation: settings ? settings.clickNavigation !== false : true

  // Resolve the monitor that hosts this bar widget. On a multi-monitor setup
  // each bar owns its own pager state; fall back to focus only while the
  // window/screen binding is not available yet.
  readonly property var monitor: {
    var win = root.QsWindow.window
    var screen = win ? win.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""
  readonly property int activeId: {
    var ws = root.monitor ? root.monitor.activeWorkspace : null
    return ws ? ws.id : -1
  }

  // Omarchy assigns each monitor a 10-workspace band (11..20, 21..30, ...).
  // The pager always draws slots 1..desktops, so translate this monitor's
  // active workspace into its band's local slot before highlighting or clicking.
  readonly property int activeSlot: activeId < 1 ? -1 : ((activeId - 1) % 10) + 1
  readonly property int workspaceBase: activeId >= 1 ? activeId - activeSlot : 0

  function clickAnimationStyle(target) {
    var current = root.activeSlot
    if (current < 1 || target < 1 || current === target) return "slide"

    var columns = root.columns
    var currentRow = Math.floor((current - 1) / columns)
    var currentColumn = (current - 1) % columns
    var targetRow = Math.floor((target - 1) / columns)
    var targetColumn = (target - 1) % columns
    var rowDelta = targetRow - currentRow
    var columnDelta = targetColumn - currentColumn

    if (rowDelta === 0) return columnDelta < 0 ? "slide left" : "slide right"
    if (columnDelta === 0) return rowDelta < 0 ? "slidevert top" : "slidevert bottom"

    // Hyprland animates workspaces on one axis only; use the larger component.
    if (Math.abs(rowDelta) > Math.abs(columnDelta))
      return rowDelta < 0 ? "slidevert top" : "slidevert bottom"
    return columnDelta < 0 ? "slide left" : "slide right"
  }

  function focusWorkspace(id) {
    var style = clickAnimationStyle(id)
    var expression = "hl.animation({ leaf = 'workspaces', enabled = true, speed = 8, bezier = 'default', style = '"
      + style + "' })\n"
    // A click on another monitor's bar must focus that monitor first; a bare
    // workspace dispatch would create the slot on the focused monitor.
    if (root.monitorName)
      expression += "hl.dispatch(hl.dsp.focus({ monitor = \"" + root.monitorName + "\" }))\n"
    expression += "hl.dispatch(hl.dsp.focus({ workspace = \"" + (root.workspaceBase + id) + "\" }))"
    if (root.bar) root.bar.run("hyprctl eval " + Util.shellQuote(expression))
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

  // Popout contract: the panel's dismissal surfaces call these on the owner
  // widget; routing through the controller keeps the panel's open binding
  // alive (a direct KeyboardPanel.open write would break it).
  function open() { openPanel() }
  function close() { closePanel() }

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
    readonly property bool active: root.activeSlot === desktopId

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
        else if (root.clickNavigation) root.focusWorkspace(parent.desktopId)
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

  // Keep every pager exact: workspace switches, monitor moves/renumbering,
  // and fullscreen events trigger a re-read of each monitor's state.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "workspacev2" || name === "fullscreen"
          || name === "moveworkspacev2" || name === "changeworkspaceid")
        Hyprland.refreshMonitors()
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
