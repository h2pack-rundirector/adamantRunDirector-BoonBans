---@meta _
---@diagnostic disable: lowercase-global
local deps = ...
local moduleRef = deps.module
local runState = deps.runState
local traitInfo = deps.traitInfo
local offerContext = deps.offerContext

local function getTraitRarityOverride(traitName, runtime, sourceInfo, tierIndex)
    local source, info = traitInfo.resolveTrait(runtime, traitName, sourceInfo, tierIndex)
    if not info or not info.controlName then
        return nil
    end

    if not source or not source:hasRarity() then
        return nil
    end

    local effectiveTierIndex = info.tierIndex or 1
    if not source:isTierConfigured(effectiveTierIndex) or source:isBanned(traitName, effectiveTierIndex) then
        return nil
    end

    return source:rarityOverride(traitName)
end

local function applyRarityOverrides(lootData, runtime, lootInfo, banPoolIndex, host)
    for _, item in ipairs(lootData.UpgradeOptions) do
        local name = item.ItemName or item.Name
        local targetRarity = getTraitRarityOverride(name, runtime, lootInfo, banPoolIndex)
        if targetRarity then
            item.Rarity = targetRarity
            item.ForceRarity = true
            host.logIf("[Rarity] Forced %s on %s", targetRarity, name)
        end
    end
end

moduleRef.hooks.wrap("SetTraitsOnLoot", function(host, runtime, base, lootData, args)
    base(lootData, args)

    -- Consume pending state unconditionally to prevent stale values on next call.
    local pendingOffer = runState.scratch.mapTake(offerContext.scratchKey, lootData) or {}
    local allowed = pendingOffer.allowed or {}
    local fullCount = pendingOffer.fullCount or 0
    local duoLegendaryQueue = pendingOffer.duoLegendaryQueue

    if not host.isEnabled() then
        return
    end

    local lootInfo = traitInfo.lookupLoot(lootData.Name)
    local banPoolIndex = traitInfo.currentTierIndex(runtime, lootInfo)

    applyRarityOverrides(lootData, runtime, lootInfo, banPoolIndex, host)

    if #allowed <= 2 and #allowed > 0 then
        local duoRarityMap = {}
        if duoLegendaryQueue then
            for _, item in ipairs(duoLegendaryQueue) do
                if item.ItemName then
                    duoRarityMap[item.ItemName] = item.rarity
                end
            end
        end

        local allowedSet = {}
        for _, item in ipairs(allowed) do
            local name = item.ItemName or item.Name or item.TraitName
            if name then allowedSet[name] = true end
        end

        local inOffer = {}
        for _, item in ipairs(lootData.UpgradeOptions) do
            local name = item.ItemName or item.Name
            if name then inOffer[name] = true end
        end

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
                return
            end

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
                host.logIf("[Micro] Injected allowed boon '%s' into slot %d", name, displaceIdx)
            end
        end

        for _, allowedItem in ipairs(allowed) do
            local name = allowedItem.ItemName or allowedItem.Name or allowedItem.TraitName
            if name and not inOffer[name] then
                injectAllowedBoon(name)
            end
        end
    end

    if fullCount > GetTotalLootChoices() then
        lootData.BlockReroll = false
    end
end)
