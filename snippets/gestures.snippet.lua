-- omarchy-workspaces-pager: three-finger swipe workspace navigation.
-- Merge into ~/.config/hypr/input.lua (or your gesture section).
-- Swipes follow the content: swipe left moves the view right, mirroring the
-- arrow-key semantics. The pager panel's swipe toggle gates these.
local nav = os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.kambiz.workspaces-pager/scripts/pager-nav"

hl.gesture({ fingers = 3, direction = "left",  action = function() hl.dispatch(hl.dsp.exec_cmd(nav .. " --via gesture right")) end })
hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.exec_cmd(nav .. " --via gesture left")) end })
hl.gesture({ fingers = 3, direction = "down",  action = function() hl.dispatch(hl.dsp.exec_cmd(nav .. " --via gesture up")) end })
hl.gesture({ fingers = 3, direction = "up",    action = function() hl.dispatch(hl.dsp.exec_cmd(nav .. " --via gesture down")) end })
