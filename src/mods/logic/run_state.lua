local internal = RunDirectorBoonBans_Internal

local PACK_ID = "run-director"
local MODULE_ID = "BoonBans"
local EMPTY_COUNTS = {}

function internal.CreateRunState(store)
    local scratch = {
        activeGodKey = nil,
    }

    local runState = {}

    local function GetCache()
        if not CurrentRun then return nil end
        local cache = lib.gameObject.get(CurrentRun, PACK_ID, MODULE_ID, "run", function()
            return {
                BanPoolPickCounts = {},
                ImproveFirstNBoonRarity = store.read("ImproveFirstNBoonRarity") or 0,
            }
        end)
        if not cache.BanPoolPickCounts then
            cache.BanPoolPickCounts = {}
        end
        if cache.ImproveFirstNBoonRarity == nil then
            cache.ImproveFirstNBoonRarity = store.read("ImproveFirstNBoonRarity") or 0
        end
        return cache
    end

    function runState.hasCurrentRun()
        return GetCache() ~= nil
    end

    function runState.getBanPoolPickCounts()
        local cache = GetCache()
        if not cache then
            return EMPTY_COUNTS
        end
        return cache.BanPoolPickCounts
    end

    function runState.getBanPoolIndex(godKey)
        if not godKey then
            return 1
        end
        return (runState.getBanPoolPickCounts()[godKey] or 0) + 1
    end

    function runState.recordAcquisition(godKey)
        local cache = GetCache()
        if not cache or not godKey then
            return nil
        end
        local counts = cache.BanPoolPickCounts
        counts[godKey] = (counts[godKey] or 0) + 1
        return counts[godKey]
    end

    function runState.setActiveGod(godKey)
        scratch.activeGodKey = godKey
    end

    function runState.getActiveGod()
        return scratch.activeGodKey
    end

    function runState.clearActiveGod()
        scratch.activeGodKey = nil
    end

    function runState.getForcedRarityRemaining()
        local cache = GetCache()
        return cache and cache.ImproveFirstNBoonRarity or 0
    end

    function runState.shouldForceRarity(loot)
        return runState.getForcedRarityRemaining() > 0 and loot and loot.GodLoot == true
    end

    function runState.consumeForcedRarity(traitName)
        local cache = GetCache()
        if not cache or not traitName or not IsGodTrait(traitName) then
            return false
        end
        if not cache.ImproveFirstNBoonRarity or cache.ImproveFirstNBoonRarity <= 0 then
            return false
        end
        cache.ImproveFirstNBoonRarity = math.max(0, cache.ImproveFirstNBoonRarity - 1)
        return true
    end

    return runState
end
