---@meta _
---@diagnostic disable: lowercase-global
local deps = ...
local moduleRef = deps.module
local runState = deps.runState
local traitInfo = deps.traitInfo
local offerContext = deps.offerContext
local padding = deps.padding

local skipIsTraitEligible = false

local function shouldBlockTraitEligibility(traitName, runtime)
    local source, info = traitInfo.resolveCurrentTrait(runtime, traitName)
    if not info then
        return false
    end

    local tierIndex = info.tierIndex or 1
    if not source or not source:isTierConfigured(tierIndex) then
        return false
    end

    return source:isBanned(traitName, tierIndex) == true
end

local function getVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData)
    skipIsTraitEligible = true
    local result = base(upgradeOptions, lootData, upgradeChoiceData)
    skipIsTraitEligible = false
    return result
end

local function generatePriorityQueue(allowed, isHammer, queueMaxSize, host)
    local queue = {}
    local duoLegendaryQueue = {}

    for _, pending in ipairs(allowed) do
        local pendingName = pending.ItemName or pending.Name or pending.TraitName
        if pendingName then
            if not isHammer then
                local trait = TraitData[pendingName]
                local isDuo = trait and (trait.IsDuoBoon == true)
                local isLegendary = trait and (trait.RarityLevels and trait.RarityLevels.Legendary ~= nil)

                if isDuo or isLegendary then
                    pending.rarity = isDuo and "Duo" or "Legendary"
                    table.insert(duoLegendaryQueue, pending)
                end
            end

            if #queue < queueMaxSize then
                table.insert(queue, pending)
            end
        end
    end

    if #queue > 0 then
        host.logIf("[Micro] PriorityQueue generated. Items: %d", #queue)
    end

    return queue, duoLegendaryQueue
end

moduleRef.hooks.wrap("GetEligibleUpgrades", function(host, runtime, base, upgradeOptions, lootData, upgradeChoiceData)
    if not host.isEnabled() then
        return base(upgradeOptions, lootData, upgradeChoiceData)
    end

    local source, lootInfo = traitInfo.resolveLoot(runtime, lootData.Name)
    local sourceName = lootInfo and lootInfo.sourceName or nil
    local isHammer = (lootData.Name == "WeaponUpgrade")
    local banPoolIndex = traitInfo.currentTierIndex(runtime, lootInfo)

    host.logIf(
        "[Micro] Inspecting Loot: %s (God: %s, Ban Pool: %d)",
        lootData.Name,
        tostring(sourceName),
        banPoolIndex
    )

    if lootInfo then
        if not source or not source:isTierConfigured(banPoolIndex) then
            host.logIf("[Micro] Early exit for %s (ban pool %d not configured)", tostring(sourceName), banPoolIndex)
            return getVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData)
        end
    end

    local fullList = getVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData) or {}

    local allowed = {}
    local banned = {}

    for _, option in ipairs(fullList) do
        local name = option and (option.ItemName or option.Name or option.TraitName)
        if name then
            local isBanned = traitInfo.isBanned(name, runtime, lootInfo, banPoolIndex)

            if not isBanned then
                table.insert(allowed, option)
            else
                table.insert(banned, option)
            end
        end
    end

    host.logIf("[Micro] Loot Result: Passed %d, Banned %d", #allowed, #banned)

    if #allowed == 0 then
        runState.scratch.mapSet(offerContext.scratchKey, lootData, {
            allowed = {},
            fullCount = #fullList,
        })
        return fullList
    end

    local queue, duoLegendaryQueue = generatePriorityQueue(
        allowed,
        isHammer,
        GetTotalLootChoices(),
        host
    )

    if padding then
        local pickCounts = runState.getBanPoolPickCounts(runtime)
        padding.extendLootQueue(queue, {
            config = padding.readConfig(runtime),
            banned = banned,
            source = source,
            sourceInfo = lootInfo,
            tierIndex = banPoolIndex,
            isHammer = isHammer,
            priorityList = lootData.PriorityUpgrades,
            queueMaxSize = GetTotalLootChoices(),
            pickCount = sourceName and pickCounts[sourceName] or 0,
            runtime = runtime,
            traitInfo = traitInfo,
        })
    end

    host.logIf("Generated Priority Queue:")
    for i, queued in ipairs(queue) do
        host.logIf("  %d. %s (Rarity: %s)", i, queued.ItemName, tostring(queued.rarity))
    end

    runState.scratch.mapSet(offerContext.scratchKey, lootData, {
        allowed = allowed,
        fullCount = #fullList,
        duoLegendaryQueue = duoLegendaryQueue,
    })

    return queue
end)

moduleRef.hooks.contextWrap("GetReplacementTraits", function(_, _, context)
    context.wrap("IsTraitEligible", function(base, traitData, args)
        return base(traitData, args)
    end)
end)

moduleRef.hooks.wrap("IsTraitEligible", function(host, runtime, base, traitData, args)
    if not host.isEnabled() or skipIsTraitEligible then return base(traitData, args) end

    if shouldBlockTraitEligibility(traitData.Name, runtime) then
        host.logIf("[Micro] IsTraitEligible BLOCKED: %s", traitData.Name)
        return false
    end

    return base(traitData, args)
end)
