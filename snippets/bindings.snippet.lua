-- omarchy-workspaces-pager: Ctrl+Alt+arrow grid navigation.
-- Merge into ~/.config/hypr/bindings.lua (or your keybind section).
-- The pager panel's "Ctrl+Alt+arrow navigation" toggle gates these.
local nav = os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.kambiz.workspaces-pager/scripts/pager-nav"

o.bind("CTRL + ALT + LEFT", "Workspaces pager: left", nav .. " --via keybind left")
o.bind("CTRL + ALT + RIGHT", "Workspaces pager: right", nav .. " --via keybind right")
o.bind("CTRL + ALT + UP", "Workspaces pager: row up", nav .. " --via keybind up")
o.bind("CTRL + ALT + DOWN", "Workspaces pager: row down", nav .. " --via keybind down")
