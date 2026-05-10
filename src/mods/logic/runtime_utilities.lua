local internal = RunDirectorBoonBans_Internal

internal.runtimeUtilities = internal.runtimeUtilities or {}
local runtimeUtilities = internal.runtimeUtilities

local PACK_ID = "run-director"
local MODULE_ID = "BoonBans"

function runtimeUtilities.GetRunState(store)
    if not CurrentRun then return nil end
    local state = lib.gameObject.get(CurrentRun, PACK_ID, MODULE_ID, "run", function()
        return {
            BoonPickCounts = {},
            ImproveFirstNBoonRarity = store.read("ImproveFirstNBoonRarity") or 0,
        }
    end)
    if not state.BoonPickCounts then
        state.BoonPickCounts = {}
    end
    if state.ImproveFirstNBoonRarity == nil then
        state.ImproveFirstNBoonRarity = store.read("ImproveFirstNBoonRarity") or 0
    end
    return state
end
