import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Control panel for the workspaces pager, opened by right-clicking the
// widget. Every change is written to the widget's entry in shell.json at
// once; lowering the workspace count also moves windows from the removed
// workspaces to the last remaining one.
Panel {
  id: root

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget ? hostWidget : root

  readonly property var cfg: hostWidget ? (hostWidget.settings || {}) : ({})
  readonly property int rows: {
    var v = parseInt(cfg.rows, 10)
    return v === 1 ? 1 : 2
  }
  readonly property int desktopCount: {
    var v = parseInt(cfg.desktops, 10)
    return v >= 1 && v <= 20 ? v : 8
  }
  readonly property bool keybinds: cfg.keybinds !== false
  readonly property bool gestures: cfg.gestures !== false

  readonly property color fg: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent

  function save(values) {
    if (root.hostWidget) root.hostWidget.saveSettings(values)
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function status() { return root.opened ? "open" : "closed" }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Move windows off workspaces above the new count, then refocus if the
  // active workspace was removed. The helper path is resolved from this
  // file's location inside the installed plugin.
  readonly property string helperDir: {
    var url = Qt.resolvedUrl("scripts").toString()
    return url.indexOf("file://") === 0 ? url.slice(7) : url
  }

  Process {
    id: migrator
    property string exe: root.helperDir + "/pager-migrate"
    onExited: console.log("workspaces-pager: migration exit", code)
  }

  function applyCount(value) {
    var previous = root.desktopCount
    root.save({ desktops: value })
    if (value < previous) {
      migrator.command = [migrator.exe, String(value)]
      migrator.running = true
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: contentColumn.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(10)

        Item { width: 1; height: Style.space(2) }

        Text {
          textFormat: Text.PlainText
          text: "Workspaces Pager"
          color: root.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Toggle {
          width: parent.width
          label: "Two-row grid"
          description: "Split the workspaces across two rows"
          checked: root.rows === 2
          onClicked: root.save({ rows: root.rows === 2 ? 1 : 2 })
        }

        Toggle {
          width: parent.width
          label: "Ctrl+Alt+arrow navigation"
          description: "Grid navigation keys (bindings snippet)"
          checked: root.keybinds
          onClicked: root.save({ keybinds: !root.keybinds })
        }

        Toggle {
          width: parent.width
          label: "Three-finger swipe navigation"
          description: "Swipe across the grid (gestures snippet)"
          checked: root.gestures
          onClicked: root.save({ gestures: !root.gestures })
        }

        NumberField {
          label: "Workspaces"
          width: parent.width
          from: 1
          to: 20
          stepSize: 1
          value: root.desktopCount
          onModified: function(value) { root.applyCount(value) }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Lowering the count moves windows on removed workspaces to the last remaining one."
          wrapMode: Text.WordWrap
          color: Qt.alpha(root.fg, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Item { width: 1; height: Style.space(2) }
      }
    }
  }
}
