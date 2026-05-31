---@meta _
---@diagnostic disable: lowercase-global
local deps = ...
local moduleRef = deps.module
local runState = deps.runState
local traitInfo = deps.traitInfo
local jpomContext = deps.jpomContext
local offerContext = deps.offerContext

local skipIsTraitEligible = false

local function getSourceControl(runtime, sourceName)
    if not sourceName then
        return nil
    end

    return runtime.controls.get(sourceName)
end

local function resolveTraitInfo(traitName, runtime)
    return traitInfo.currentControlFromTrait(traitName, runtime)
end

local function shouldBlockTraitEligibility(traitName, runtime, opts)
    opts = opts or {}
    local info = resolveTraitInfo(traitName, runtime)
    if not info then
        return false
    end

    if opts.isKeepsakeOffering and info.tierKey == "Hades" then
        local keepsake = getSourceControl(runtime, "HadesKeepsake")
        return keepsake ~= nil and keepsake:isBanned(traitName, 1) == true
    end

    local source = getSourceControl(runtime, info.controlName)
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

    local currentGodKey = traitInfo.controlFromLoot(lootData.Name)
    local isHammer = (lootData.Name == "WeaponUpgrade")
    local banPoolIndex = runState.getBanPoolIndex(runtime, currentGodKey)

    host.logIf(
        "[Micro] Inspecting Loot: %s (God: %s, Ban Pool: %d)",
        lootData.Name,
        tostring(currentGodKey),
        banPoolIndex
    )

    if currentGodKey then
        local source = getSourceControl(runtime, currentGodKey)
        if not source or not source:isTierConfigured(banPoolIndex) then
            host.logIf("[Micro] Early exit for %s (ban pool %d not configured)", tostring(currentGodKey), banPoolIndex)
            return getVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData)
        end
    end

    local fullList = getVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData) or {}

    local allowed = {}
    local banned = {}
    local configCache = {}

    for _, option in ipairs(fullList) do
        local name = option and (option.ItemName or option.Name or option.TraitName)
        if name then
            local isBanned = traitInfo.isBanned(name, runtime, {
                filterGodKey = currentGodKey,
                banPoolIndex = banPoolIndex,
                cache = configCache,
            })

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

moduleRef.hooks.wrap("GetReplacementTraits", function(_, _, base, traitNames, onlyFromLootName)
    skipIsTraitEligible = true
    local result = base(traitNames, onlyFromLootName)
    skipIsTraitEligible = false
    return result
end)

moduleRef.hooks.wrap("IsTraitEligible", function(host, runtime, base, traitData, args)
    if not host.isEnabled() or skipIsTraitEligible then return base(traitData, args) end

    if shouldBlockTraitEligibility(traitData.Name, runtime, {
        isKeepsakeOffering = jpomContext.isJpomOffering,
    }) then
        host.logIf("[Micro] IsTraitEligible BLOCKED: %s", traitData.Name)
        return false
    end

    return base(traitData, args)
end)
