local padding = {}

local function getOptionName(option)
    return option and (option.ItemName or option.Name or option.TraitName) or nil
end

local function shuffleList(list)
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function isDuoOrLegendary(name, traitData)
    local trait = name and traitData[name] or nil
    return trait and (trait.IsDuoBoon or (trait.RarityLevels and trait.RarityLevels.Legendary ~= nil)) or false
end

local function buildPrioritySet(priorityList)
    local set = {}
    for _, name in ipairs(priorityList or {}) do
        set[name] = true
    end
    return set
end

local function isAllowedInFutureTier(name, opts)
    local runtime = opts.runtime
    local traitInfo = opts.traitInfo
    local sourceInfo = opts.sourceInfo
    local tierIndex = math.floor(tonumber(opts.tierIndex) or 1)
    local source = opts.source
    local tierCount = source and source:tierCount() or tierIndex

    if not name or not runtime or not traitInfo or not sourceInfo then
        return false
    end

    for futureIndex = tierIndex + 1, tierCount do
        local futureSource, futureInfo = traitInfo.resolveTrait(runtime, name, sourceInfo, futureIndex)
        if futureSource and futureInfo and futureSource:isTierConfigured(futureIndex)
            and futureSource:isBanned(name, futureIndex) ~= true then
            return true
        end
    end
    return false
end

function padding.readConfig(runtime)
    local data = runtime and runtime.data or nil
    if not data then
        return {
            enabled = false,
            prioritizeCoreForFirstN = 0,
            avoidFutureAllowed = true,
            allowDuos = false,
        }
    end

    return {
        enabled = data.get("EnablePadding"):read() == true,
        prioritizeCoreForFirstN = data.get("Padding_PrioritizeCoreForFirstN"):read() or 0,
        avoidFutureAllowed = data.get("Padding_AvoidFutureAllowed"):read() ~= false,
        allowDuos = data.get("Padding_AllowDuos"):read() == true,
    }
end

function padding.extendLootQueue(queue, opts)
    opts = opts or {}
    local config = opts.config or {}
    local banned = opts.banned or {}
    local queueMaxSize = opts.queueMaxSize or #queue
    if #queue >= queueMaxSize or #banned == 0 or config.enabled ~= true then
        return
    end

    local isHammer = opts.isHammer == true
    local usePriority = not isHammer
        and (config.prioritizeCoreForFirstN or 0) > 0
        and (opts.pickCount or 0) < config.prioritizeCoreForFirstN
    local prioritySet = usePriority and buildPrioritySet(opts.priorityList) or nil

    local highPriority = {}
    local lowPriority = {}
    for _, pending in ipairs(banned) do
        local name = getOptionName(pending)
        if usePriority and name and prioritySet[name] then
            highPriority[#highPriority + 1] = pending
        else
            lowPriority[#lowPriority + 1] = pending
        end
    end

    shuffleList(highPriority)
    shuffleList(lowPriority)

    local traitData = opts.traitData or TraitData or {}

    local function appendFrom(pool)
        for _, pending in ipairs(pool) do
            if #queue >= queueMaxSize then
                return
            end

            local name = getOptionName(pending)
            local skip = false
            if not isHammer then
                if not config.allowDuos and isDuoOrLegendary(name, traitData) then
                    skip = true
                end
                if config.avoidFutureAllowed and not skip and isAllowedInFutureTier(name, opts) then
                    skip = true
                end
            end

            if not skip then
                queue[#queue + 1] = pending
            end
        end
    end

    appendFrom(highPriority)
    appendFrom(lowPriority)
end

function padding.extendChoiceList(allowed, banned, opts)
    opts = opts or {}
    local config = opts.config or {}
    local maxSize = opts.maxSize or #allowed
    local force = opts.force == true

    if #allowed == 0 or #allowed >= maxSize or #banned == 0 then
        return allowed
    end
    if not force and config.enabled ~= true then
        return allowed
    end

    local pool = {}
    for _, item in ipairs(banned) do
        pool[#pool + 1] = item
    end

    local seen = {}
    for _, item in ipairs(allowed) do
        local key = getOptionName(item) or item
        seen[key] = true
    end

    while #allowed < maxSize and #pool > 0 do
        local index = math.random(1, #pool)
        local pick = pool[index]
        local key = getOptionName(pick) or pick
        if pick and not seen[key] then
            allowed[#allowed + 1] = pick
            seen[key] = true
        end
        pool[index] = pool[#pool]
        pool[#pool] = nil
    end

    return allowed
end

return padding
