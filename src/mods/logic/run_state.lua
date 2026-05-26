local EMPTY_COUNTS = {}
local RUN_STATE_CACHE = "RunState"

local function ReadStore(store, alias)
    return store.get(alias):read()
end

local function buildCacheDeclarations()
    return {
        [RUN_STATE_CACHE] = {
            domain = "currentRun",
            key = "run",
            factory = function()
                return {
                    BanPoolPickCounts = {},
                }
            end,
        },
    }
end

local function create(store)
    local scratch = {
        values = {},
        maps = {},
    }

    local runState = {}
    runState.scratch = {}

    local function GetCache()
        local cache = store.cache.currentRun.get(RUN_STATE_CACHE)
        if not cache then return nil end
        if not cache.BanPoolPickCounts then
            cache.BanPoolPickCounts = {}
        end
        if cache.ImproveFirstNBoonRarity == nil then
            cache.ImproveFirstNBoonRarity = ReadStore(store, "ImproveFirstNBoonRarity") or 0
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

    function runState.scratch.clear(name)
        scratch.values[name] = nil
        scratch.maps[name] = nil
    end

    function runState.scratch.set(name, value)
        scratch.values[name] = value
    end

    function runState.scratch.get(name)
        return scratch.values[name]
    end

    function runState.scratch.mapSet(name, key, value)
        if scratch.maps[name] == nil then
            scratch.maps[name] = {}
        end
        scratch.maps[name][key] = value
    end

    function runState.scratch.mapGet(name, key)
        local values = scratch.maps[name]
        return values and values[key] or nil
    end

    function runState.scratch.mapTake(name, key)
        local values = scratch.maps[name]
        if values == nil then
            return nil
        end
        local value = values[key]
        values[key] = nil
        return value
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

return {
    buildCacheDeclarations = buildCacheDeclarations,
    create = create,
}
