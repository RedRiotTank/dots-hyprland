-- ====================================================================
-- QUICKSHELL VARIABLES AND DAEMONS
-- ====================================================================
local qsIpcCall = "qs -c $qsConfig ipc call"
local qsIsAlive = qsIpcCall .. " TEST_ALIVE"

-- ====================================================================
-- 1. CLEANUP UNWANTED AND DUPLICATE KEYBINDS
-- ====================================================================
hl.unbind("Print")                                  -- Remove fullscreen screenshot on Print
hl.unbind("SUPER + Slash")                          -- Remove cheatsheet on awkward slash key
hl.unbind("SUPER + K")                              -- Remove on-screen keyboard
hl.unbind("SUPER + B")                              -- Remove duplicate sidebar toggle
hl.unbind("SUPER + O")                              -- Remove duplicate sidebar toggle
hl.unbind("SUPER + T")                              -- Remove duplicate terminal launcher
hl.unbind("CTRL + ALT + T")                         -- Remove duplicate terminal launcher
hl.unbind("SUPER + X")                              -- Remove generic text editor
hl.unbind("SUPER + Semicolon")                      -- Remove broken split ratio on ES keyboard
hl.unbind("SUPER + Apostrophe")                     -- Remove legacy split ratio
hl.unbind("SHIFT + SUPER + ALT + Slash")            -- Remove welcome screen

-- ====================================================================
-- 2. SCREENSHOTS
-- ====================================================================
-- Print: quick region snip to the clipboard
hl.bind("Print", hl.dsp.exec_cmd("hyprshot --freeze --clipboard-only --mode region --silent"), { description = "Screenshot: Quick snip to clipboard" })

-- Super + Print: open the interactive editor to annotate
hl.bind("SUPER + Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | satty --filename -"), { description = "Screenshot: Snip and annotate" })

-- ====================================================================
-- 3. HELP AND CHEATSHEET
-- ====================================================================
-- Super + F1 (universal) and Super + H (help)
hl.bind("SUPER + F1", hl.dsp.global("quickshell:cheatsheetToggle"), { description = "Shell: Toggle cheatsheet" })
hl.bind("SUPER + H", hl.dsp.global("quickshell:cheatsheetToggle"), { description = "Shell: Toggle cheatsheet" })

-- ====================================================================
-- 4. WINDOW RESIZE (USING HL.DISPATCH)
-- ====================================================================
hl.unbind("SUPER + ALT + Left")
hl.unbind("SUPER + ALT + Right")

hl.bind("SUPER + ALT + Left", function()
    hl.dispatch("resizeactive", "-40 0")
end, { repeating = true, description = "Window: Resize Left" })

hl.bind("SUPER + ALT + Right", function()
    hl.dispatch("resizeactive", "40 0")
end, { repeating = true, description = "Window: Resize Right" })

-- ====================================================================
-- 5. APPLICATIONS AND PRODUCTIVITY
-- ====================================================================
-- Launch IntelliJ IDEA (supports native, Toolbox, or Flatpak installs)
local launchIntellij = "idea || intellij-idea-ultimate-edition || intellij-idea-community-edition || flatpak run com.jetbrains.IntelliJ-IDEA-Community"

hl.bind("SUPER + SHIFT + I", hl.dsp.exec_cmd(launchIntellij), { description = "App: IntelliJ IDEA" })
hl.bind("SUPER + B", hl.dsp.exec_cmd(launchIntellij), { description = "App: IntelliJ IDEA" })

-- File manager on Super + K (in addition to the default Super + E)
hl.bind("SUPER + K", hl.dsp.exec_cmd("dolphin"), { description = "App: File manager (Dolphin)" })

-- ====================================================================
-- 6. WORKSPACE SWITCHING (SUPER + ARROWS ONLY)
-- ====================================================================
hl.unbind("SUPER + Left")
hl.unbind("SUPER + Right")

-- Move both displays simultaneously with arrows
hl.bind("SUPER + Right", hl.dsp.exec_cmd("hyprctl --batch 'dispatch focusmonitor HDMI-A-2; dispatch workspace +2; dispatch focusmonitor DP-1; dispatch workspace +2'"), { description = "Workspace: Next pair" })
hl.bind("SUPER + Left", hl.dsp.exec_cmd("hyprctl --batch 'dispatch focusmonitor HDMI-A-2; dispatch workspace -2; dispatch focusmonitor DP-1; dispatch workspace -2'"), { description = "Workspace: Previous pair" })

-- ====================================================================
-- 7. WEEB / SOBER MODES AND WALLPAPERS
-- ====================================================================
-- Toggle between the weeb and sober profiles.
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/hypr/custom/scripts/mode-toggle.sh"), { description = "Theme: Toggle weeb/sober mode" })

-- Open waypaper using the wallpaper folder of the current mode.
hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd("$HOME/.config/hypr/custom/scripts/waypaper-mode.sh"), { description = "Wallpaper: Open waypaper for current mode" })

-- ====================================================================
