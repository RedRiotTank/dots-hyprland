HOME = os.getenv("HOME")

function is_file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end

function create_if_not_exists(path)
   if not is_file_exists(path) then
      os.execute("mkdir -p \"$(dirname \"" .. path .. "\")\"")
      os.execute("echo '-- This file will not be overwritten across dots-hyprland updates.\n-- The file name is for the sake of organization and does not matter\n-- See the corresponding files in ~/.config/hypr/hyprland for examples' > \"" .. path .. "\"")
      return true
   end
   return false
end

-- Each monitor owns the numeric block:
--   monitor id 0 -> 1..workspaceGroupSize
--   monitor id 1 -> workspaceGroupSize+1..2*workspaceGroupSize
-- Keeping the blocks disjoint is required because Hyprland workspace ids are
-- global, even though the bar shows them as local 1..N on every monitor.
function workspace_base_for_monitor(monitor)
    monitor = monitor or hl.get_active_monitor()
    local monitor_id = monitor and monitor.id or 0
    return monitor_id * workspaceGroupSize
end

function workspace_local_id(i, monitor)
    return workspace_base_for_monitor(monitor) + i
end

function workspace_in_group(i)
    return workspace_local_id(i)
end

function active_local_workspace_index(monitor)
    monitor = monitor or hl.get_active_monitor()
    if not monitor then return 1 end
    local workspace = monitor.active_workspace or hl.get_active_workspace(monitor)
    local workspace_id = workspace and workspace.id or (workspace_base_for_monitor(monitor) + 1)
    local index = workspace_id - workspace_base_for_monitor(monitor)
    if index < 1 or index > workspaceGroupSize then
        index = ((workspace_id - 1) % workspaceGroupSize) + 1
    end
    return index
end

function workspace_relative(offset, monitor)
    local index = active_local_workspace_index(monitor) + offset
    while index < 1 do index = index + workspaceGroupSize end
    while index > workspaceGroupSize do index = index - workspaceGroupSize end
    return workspace_local_id(index, monitor)
end
