---@meta _
---@diagnostic disable: lowercase-global
local banConfig = nil
local banPools = nil
local godDefs = nil

local isKeepsakeOffering = false
local skipIsTraitEligible = false

local LOOT_OFFERS = "lootOffers"

local function GetVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData)
    skipIsTraitEligible = true
    local result = base(upgradeOptions, lootData, upgradeChoiceData)
    skipIsTraitEligible = false
    return result
end

local function GeneratePriorityQueue(allowed, isHammer, queueMaxSize, host)
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

local module = {}

function module.bind(data)
    banConfig = data.banConfig
    banPools = data.banPools
    godDefs = data.godDefs
    return module
end

function module.registerHooks(host, store, runState, banResolver)

    host.hooks.wrap("GetEligibleUpgrades", function(base, upgradeOptions, lootData, upgradeChoiceData)
    if not host.isEnabled() then return base(upgradeOptions, lootData, upgradeChoiceData) end

    local currentGodKey = banResolver.getGodFromLootsource(lootData.Name)
    local isHammer = (lootData.Name == "WeaponUpgrade")

    local banPoolIndex = runState.getBanPoolIndex(currentGodKey)

    host.logIf("[Micro] Inspecting Loot: %s (God: %s, Ban Pool: %d)", lootData.Name, tostring(currentGodKey), banPoolIndex)

    if currentGodKey then
        if not banConfig.IsBanPoolConfigured(currentGodKey, banPoolIndex, store) then
            host.logIf("[Micro] Early exit for %s (ban pool %d not configured)", tostring(currentGodKey), banPoolIndex)
            return GetVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData)
        end

        local banPoolKey = banPools.getBanPoolKey(currentGodKey, banPoolIndex)
        if not godDefs[banPoolKey] then
            host.logIf("[Micro] Early exit for %s (ban pool %d not configured)", tostring(currentGodKey), banPoolIndex)
            return GetVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData)
        end
    end

    local fullList = GetVanillaEligibleUpgrades(base, upgradeOptions, lootData, upgradeChoiceData) or {}

    local allowed = {}
    local banned = {}
    local configCache = {}

    for _, option in ipairs(fullList) do
        local name = option and (option.ItemName or option.Name or option.TraitName)
        if name then
            local isBanned = banResolver.isTraitBanned(name, {
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
        runState.scratch.mapSet(LOOT_OFFERS, lootData, {
            allowed = {},
            fullCount = #fullList,
        })
        return fullList
    end

    local queue, duoLegendaryQueue = GeneratePriorityQueue(
        allowed,
        isHammer,
        GetTotalLootChoices(),
        host
    )

    host.logIf("Generated Priority Queue:")
    for i, queued in ipairs(queue) do
        host.logIf("  %d. %s (Rarity: %s)", i, queued.ItemName, tostring(queued.rarity))
    end

    runState.scratch.mapSet(LOOT_OFFERS, lootData, {
        allowed = allowed,
        fullCount = #fullList,
        duoLegendaryQueue = duoLegendaryQueue,
    })

    return queue
end)

    host.hooks.wrap("GetReplacementTraits", function(base, traitNames, onlyFromLootName)
    skipIsTraitEligible = true
    local result = base(traitNames, onlyFromLootName)
    skipIsTraitEligible = false
    return result
end)

    host.hooks.wrap("SetTraitsOnLoot", function(base, lootData, args)
    base(lootData, args)

    -- Consume pending state unconditionally to prevent stale values on next call.
    local pendingOffer = runState.scratch.mapTake(LOOT_OFFERS, lootData) or {}
    local allowed = pendingOffer.allowed or {}
    local fullCount = pendingOffer.fullCount or 0
    local duoLegendaryQueue = pendingOffer.duoLegendaryQueue

    if not host.isEnabled() then return end

    local currentGodKey = banResolver.getGodFromLootsource(lootData.Name)
    local banPoolIndex = runState.getBanPoolIndex(currentGodKey)

    -- Rarity overrides: force configured rarity on unbanned boons that have a rarity setting.
    for _, item in ipairs(lootData.UpgradeOptions) do
        local name = item.ItemName or item.Name
        local targetRarity = banResolver.getTraitRarityOverride(name, {
            currentGodKey = currentGodKey,
            banPoolIndex = banPoolIndex,
        })
        if targetRarity then
            item.Rarity = targetRarity
            item.ForceRarity = true
            host.logIf("[Rarity] Forced %s on %s", targetRarity, name)
        end
    end

    -- Guarantee: if #allowed <= 2 and any allowed boon is absent from the offer (e.g. displaced
    -- by the vanilla replacement mechanic or failed the vanilla duo/legendary chance gate),
    -- inject it by displacing a non-allowed slot. Replacement slots (TraitToReplace) and other
    -- allowed boons are never displaced.
    if #allowed <= 2 and #allowed > 0 then
        -- Build a rarity map from the duo/legendary queue so injected items get correct rarity.
        local duoRarityMap = {}
        if duoLegendaryQueue then
            for _, item in ipairs(duoLegendaryQueue) do
                if item.ItemName then
                    duoRarityMap[item.ItemName] = item.rarity
                end
            end
        end

        -- Build allowed set for displacement guard (built once before injection starts).
        local allowedSet = {}
        for _, item in ipairs(allowed) do
            local name = item.ItemName or item.Name or item.TraitName
            if name then allowedSet[name] = true end
        end

        -- Track what is currently in the offer.
        local inOffer = {}
        for _, item in ipairs(lootData.UpgradeOptions) do
            local name = item.ItemName or item.Name
            if name then inOffer[name] = true end
        end

        -- Find the single vanilla replacement slot (first TraitToReplace item). Only this
        -- index is protected from displacement — not all items with TraitToReplace.
        local replacementIdx = nil
        for i, item in ipairs(lootData.UpgradeOptions) do
            if item.TraitToReplace then
                replacementIdx = i
                break
            end
        end

        local maxChoices = GetTotalLootChoices()

        local function injectAllowedBoon(name)
            local duoRarity = duoRarityMap[name]
            local newOption = { ItemName = name, Type = "Trait" }
            if duoRarity then
                newOption.Rarity = duoRarity
                newOption.ForceRarity = true
            end

            if #lootData.UpgradeOptions < maxChoices then
                table.insert(lootData.UpgradeOptions, newOption)
                inOffer[name] = true
                host.logIf("[Micro] Injected allowed boon '%s' into empty slot", name)
            else
                -- Displace the last non-allowed slot: not the protected replacement index, not an allowed boon.
                local displaceIdx = nil
                for i = #lootData.UpgradeOptions, 1, -1 do
                    local item = lootData.UpgradeOptions[i]
                    local itemName = item.ItemName or item.Name
                    if itemName and i ~= replacementIdx and not allowedSet[itemName] then
                        displaceIdx = i
                        break
                    end
                end
                if displaceIdx then
                    lootData.UpgradeOptions[displaceIdx] = newOption
                    inOffer[name] = true
                    host.logIf("[Micro] Injected allowed boon '%s' into slot %d (displaced non-allowed option)", name, displaceIdx)
                end
            end
        end

        for _, allowedItem in ipairs(allowed) do
            local name = allowedItem.ItemName or allowedItem.Name or allowedItem.TraitName
            if name and not inOffer[name] then
                injectAllowedBoon(name)
            end
        end
    end

    -- BlockReroll: vanilla sets this to true when its internal pool is exhausted, but our
    -- GetEligibleUpgrades filter makes the pool look artificially empty. Use fullCount
    -- (the unfiltered eligible pool size) as the real signal: if the full pool is larger
    -- than the offer, a reroll can surface different choices.
    if fullCount > GetTotalLootChoices() then
        lootData.BlockReroll = false
    end
end)

    host.hooks.wrap("IsTraitEligible", function(base, traitData, args)
    if not host.isEnabled() or skipIsTraitEligible then return base(traitData, args) end

    if banResolver.shouldBlockTraitEligibility(traitData.Name, { isKeepsakeOffering = isKeepsakeOffering }) then
        host.logIf("[Micro] IsTraitEligible BLOCKED: %s", traitData.Name)
        return false
    end

    return base(traitData, args)
end)

    host.hooks.wrap("GiveRandomHadesBoonAndBoostBoons", function(base, args)
    isKeepsakeOffering = true
    local result = base(args)
    isKeepsakeOffering = false
    return result
end)

    host.hooks.wrap("GetRarityChances", function(base, loot)
    local chances = base(loot)
    if host.isEnabled() and runState.shouldForceRarity(loot) then
        chances.Common, chances.Rare, chances.Epic = 0.0, 0.0, 1.0
    end
    return chances
end)

    host.hooks.wrap("HeraSuperchargeBoon", function(base, args, origTraitData, contextArgs)
    local targetBoon = store.read("BridalGlowTargetBoon")
    if not targetBoon or targetBoon == "" then
        base(args, origTraitData, contextArgs)
        return
    end

    local targetTrait = GetHeroTrait(targetBoon)
    if not targetTrait or targetTrait.BlockStacking == true then
        base(args, origTraitData, contextArgs)
        return
    end

    contextArgs = contextArgs or {}

    local traitData = AddRarityToTraits(targetTrait, {
        ForceUpgrade = { targetTrait },
        TargetRarity = 4,
        Silent = true,
    })

    if not traitData then
        base(args, origTraitData, contextArgs)
        return
    end

    thread(AddStackToTraits, { TraitName = traitData.Name, NumStacks = args.Stacks, Silent = true })
    IncreaseTraitLevel(traitData, args.Stacks)

    origTraitData.UpgradedTraitName = traitData.Name
    thread(HeraTraitRarityPresentation, traitData.Name, args.Stacks, contextArgs.Delay)
end)

end

return module
