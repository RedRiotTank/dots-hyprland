-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter.
-- See the corresponding files in ~/.config/hypr/hyprland for examples.

hl.config({
    input = {
        kb_layout = "es",
    }
})

-- MONITOR CONFIG

-- AsRock Phantom Gaming 2K (center) at 165Hz - primary
hl.monitor({
    output = "DP-1",
    mode = "2560x1440@165",
    position = "3840x360",
    scale = 1
})

-- LG Full HD 1080p (right) at 60Hz
hl.monitor({
    output = "HDMI-A-2",
    mode = "1920x1080@60",
    position = "6400x540",
    scale = 1
})
