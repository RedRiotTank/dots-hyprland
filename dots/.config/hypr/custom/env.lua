-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter.
-- See the corresponding files in ~/.config/hypr/hyprland for examples.
--
-- AQ_DRM_DEVICES / AQ_NO_MODIFIERS / AQ_MGPU_NO_EXPLICIT live in
-- ~/.config/uwsm/env.local: Hyprland applies `env =` too late (Aquamarine
-- has already read those variables when it initializes the DRM/EGL backend),
-- so setting them here had no effect.

hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "ibus")
