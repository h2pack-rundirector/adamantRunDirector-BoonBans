local EMPTY_COUNTS = {}
local RUN_STATE_CACHE = "RunState"

local function ReadRuntime(runtime, alias)
    local data = runtime and runtime.data or nil
    return data and data.get(alias):read() or nil
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

local function create()
    local scratch = {
        values = {},
        maps = {},
    }

    local runState = {}
    runState.scratch = {}

    local function GetCache(runtime)
        local cache = runtime and runtime.cache and runtime.cache.currentRun.get(RUN_STATE_CACHE) or nil
        if not cache then return nil end
        if not cache.BanPoolPickCounts then
            cache.BanPoolPickCounts = {}
        end
        if cache.ImproveFirstNBoonRarity == nil then
            cache.ImproveFirstNBoonRarity = ReadRuntime(runtime, "ImproveFirstNBoonRarity") or 0
        end
        return cache
    end

    function runState.hasCurrentRun(runtime)
        return GetCache(runtime) ~= nil
    end

    function runState.getBanPoolPickCounts(runtime)
        local cache = GetCache(runtime)
        if not cache then
            return EMPTY_COUNTS
        end
        return cache.BanPoolPickCounts
    end

    function runState.getBanPoolIndex(runtime, godKey)
        if not godKey then
            return 1
        end
        return (runState.getBanPoolPickCounts(runtime)[godKey] or 0) + 1
    end

    function runState.recordAcquisition(runtime, godKey)
        local cache = GetCache(runtime)
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

    function runState.getForcedRarityRemaining(runtime)
        local cache = GetCache(runtime)
        return cache and cache.ImproveFirstNBoonRarity or 0
    end

    function runState.shouldForceRarity(runtime, loot)
        return runState.getForcedRarityRemaining(runtime) > 0 and loot and loot.GodLoot == true
    end

    function runState.consumeForcedRarity(runtime, traitName)
        local cache = GetCache(runtime)
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
