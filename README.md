# Workspaces Pager (omarchy)

A grid workspace pager for [Omarchy](https://omarchy.org) 4.5+ (Quattro shell):
a KDE-style block per virtual desktop laid out over one or two rows, with a
control panel for the layout and the navigation inputs.

- **Dynamic grid.** Row count (1–2) and workspace count are settings; the
  columns per row follow as `ceil(workspaces / rows)` — 8 workspaces in 2 rows
  render 4 + 4, 5 workspaces render 3 + 2.
- **Control panel.** Right-click the widget: two-row toggle, workspace-count
  spinner, and toggles for the keyboard and swipe navigation.
- **Migration.** Lowering the workspace count moves windows from removed
  workspaces to the last remaining one and refocuses if needed.
- **Navigation.** `Ctrl+Alt+<arrow>` and three-finger swipes walk the grid
  with hard stops at the edges (no wraparound); swipes follow the content.
  Each input has its own toggle in the panel.

The widget is a bar-widget plugin for Omarchy's shell; the navigation helpers
are plain scripts driven by snippets you add to your Hyprland config once.

## Install

```sh
git clone https://github.com/<owner>/omarchy-workspaces-pager.git
cp -r omarchy-workspaces-pager ~/.config/omarchy/plugins/io.github.kambiz.workspaces-pager
```

Add the widget to the bar (left section sits next to the workspaces indicator):

```sh
omarchy bar put io.github.kambiz.workspaces-pager left
```

Or use `omarchy bar move <id> <placement>` / the bar editor later. Settings
default to 2 rows and 8 workspaces; the control panel changes them.

## Enable the navigation inputs

The panel toggles gate the helpers; the inputs themselves are one-time
snippet merges.

`~/.config/hypr/bindings.lua` — append
[`snippets/bindings.snippet.lua`](snippets/bindings.snippet.lua).

`~/.config/hypr/input.lua` — append
[`snippets/gestures.snippet.lua`](snippets/gestures.snippet.lua).

Then reload Hyprland (`hyprctl reload` or `Super+Shift+R` on Omarchy). The
snippets point at the installed plugin's `scripts/pager-nav`, which reads the
grid geometry and the toggles from this plugin's entry in `shell.json` — no
duplication, and the panel controls the behavior live.

If you previously used a standalone `omarchy-ws-move` script with hardcoded
geometry, remove its binds/gestures in favor of these.

## Settings

Stored on the widget's bar entry (`~/.config/omarchy/shell.json`), editable
from the panel:

| Key        | Values       | Meaning                                    |
| ---------- | ------------ | ------------------------------------------ |
| `rows`     | `1` or `2`   | Pager rows                                  |
| `desktops` | `1`–`20`     | Workspaces the pager shows                  |
| `keybinds` | boolean      | Gate for `--via keybind` helper calls       |
| `gestures` | boolean      | Gate for `--via gesture` helper calls       |

Lowering `desktops` runs `scripts/pager-migrate`: windows on workspaces above
the new count move to workspace `count`, and the focused view follows if it
was on a removed workspace.

## IPC

The widget registers a Quickshell IPC target for scripting and testing
(requires a shell restart to register after install):

```sh
qs -p /usr/share/omarchy/shell ipc call io.github.kambiz.workspaces-pager toggle
qs -p /usr/share/omarchy/shell ipc call io.github.kambiz.workspaces-pager panelStatus
qs -p /usr/share/omarchy/shell ipc call io.github.kambiz.workspaces-pager applySettings '{"rows":1}'
```

`open`, `close`, `toggle`, `panelStatus`, and `applySettings` (a JSON object
merged into the widget's entry, same path the panel uses).

## Files

```
Pager.qml                      bar widget: the grid + panel plumbing
Panel.qml                      control panel (rows, count, toggles)
scripts/pager-nav              grid-aware workspace switch, flag-gated
scripts/pager-migrate          window migration on count decrease
snippets/*.snippet.lua         one-time Hyprland config merges
tests/run                      manifest/scripts validation
```

## Compatibility

Omarchy 4.5+ with the Quattro shell on Hyprland 0.56 (the `hyprctl eval`
lua bridge). The pager itself only needs the shell; the navigation helpers
need `hyprctl`, `jq`, and the snippet entries above.

## Uninstall

```sh
omarchy bar remove io.github.kambiz.workspaces-pager
rm -rf ~/.config/omarchy/plugins/io.github.kambiz.workspaces-pager
```

And remove the snippet lines from your Hyprland config.

## License

MIT
