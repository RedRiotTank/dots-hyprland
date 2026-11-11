-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter.
-- See the corresponding files in ~/.config/hypr/hyprland for examples.

-- Per-monitor workspaces
-- Hyprland workspace ids are global, so each monitor gets a disjoint block:
--   monitor id 0 -> 1..10, monitor id 1 -> 11..20, monitor id 2 -> 21..30...
-- The bar and the Lua helpers translate those global ids back to 1..N for
-- the monitor the user is looking at.
local function create_monitor_workspaces(monitor)
    if not monitor or not monitor.name then return end
    local base = (monitor.id or 0) * workspaceGroupSize
    for i = 1, workspaceGroupSize do
        hl.workspace_rule({
            workspace = tostring(base + i),
            monitor = monitor.name,
            default = (i == 1),
        })
    end
end

for _, monitor in ipairs(hl.get_monitors()) do
    create_monitor_workspaces(monitor)
end
hl.on("monitor.added", create_monitor_workspaces)

-- Kitty opacity
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "0.88 0.78", no_blur = true })
