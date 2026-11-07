-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter.
-- See the corresponding files in ~/.config/hypr/hyprland for examples.

-- Phantom Gaming (left): odd workspaces
hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1" })
hl.workspace_rule({ workspace = "5", monitor = "DP-1" })
hl.workspace_rule({ workspace = "7", monitor = "DP-1" })
hl.workspace_rule({ workspace = "9", monitor = "DP-1" })

-- LG (right): even workspaces
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-2", default = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-2" })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-2" })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-2" })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-2" })

-- Kitty opacity
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "0.88 0.78", no_blur = true })
