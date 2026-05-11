local bit32 = require("bit32")
local lshift = bit32.lshift

local catalogExtractor = {}

local function BuildBoonEntry(godKey, boonKey, index, overrideDisplayName)
    local traitData = TraitData[boonKey]
    local rarity = {
        isDuo = false,
        isLegendary = false,
        isElemental = false,
        blockStacking = false,
    }
    if traitData then
        rarity.isDuo = traitData.IsDuoBoon or false
        rarity.isLegendary = (traitData.RarityLevels and traitData.RarityLevels.Legendary ~= nil) or false
        rarity.isElemental = traitData.IsElementalTrait or false
        rarity.blockStacking = traitData.BlockStacking == true
    end

    local displayName = overrideDisplayName or (traitData and game.GetDisplayName({ Text = boonKey })) or boonKey
    local boon = {
        Key = boonKey,
        God = godKey,
        Bit = index,
        Mask = lshift(1, index),
        Name = displayName,
        NameLower = string.lower(displayName),
        Rarity = rarity,
        IsBridalGlowEligible = false,
    }

    if rarity.isDuo then
        boon.IsSpecial = true
        boon.IsRarityEligible = false
        boon.SpecialDisplayLabel = displayName
        boon.SpecialTooltip = "Duo Boon"
        boon.SpecialBadgeText = " D "
        boon.SpecialBadgeColor = { 0.82, 1.0, 0.38, 1.0 }
    elseif rarity.isLegendary then
        boon.IsSpecial = true
        boon.IsRarityEligible = false
        boon.SpecialDisplayLabel = displayName
        boon.SpecialTooltip = "Legendary Boon"
        boon.SpecialBadgeText = " L "
        boon.SpecialBadgeColor = { 1.0, 0.56, 0.0, 1.0 }
    elseif rarity.isElemental then
        boon.IsSpecial = true
        boon.IsRarityEligible = false
        boon.SpecialDisplayLabel = displayName
        boon.SpecialTooltip = "Elemental Infusion"
        boon.SpecialBadgeText = " I "
        boon.SpecialBadgeColor = { 1.0, 0.29, 1.0, 1.0 }
    else
        boon.IsSpecial = false
        boon.IsRarityEligible = true
        boon.SpecialDisplayLabel = displayName
    end

    boon.IsBridalGlowEligible = boon.IsRarityEligible == true and rarity.blockStacking ~= true
    return boon
end

local function AddEntryBoon(entry, boon)
    entry.boons[#entry.boons + 1] = boon
    entry.boonByKey[boon.Key] = boon
end

local function AddLootSetBoons(entry, godKey, meta, src)
    local lootData = LootSetData[meta.key]
    if not lootData or not lootData[src.key] then
        return
    end

    local upgradeData = lootData[src.key]
    local index = 0
    if upgradeData.WeaponUpgrades then
        for _, boonKey in ipairs(upgradeData.WeaponUpgrades) do
            AddEntryBoon(entry, BuildBoonEntry(godKey, boonKey, index))
            index = index + 1
        end
    end
    if upgradeData.Traits then
        for _, boonKey in ipairs(upgradeData.Traits) do
            AddEntryBoon(entry, BuildBoonEntry(godKey, boonKey, index))
            index = index + 1
        end
    end
    if src.subKey and upgradeData[src.subKey] then
        for _, boonKey in ipairs(upgradeData[src.subKey]) do
            AddEntryBoon(entry, BuildBoonEntry(godKey, boonKey, index))
            index = index + 1
        end
    end
end

local function AddUnitSetBoons(entry, godKey, src)
    if not UnitSetData[src.unitKey] or not UnitSetData[src.unitKey][src.unitSetKey] then
        return
    end
    local traitList = UnitSetData[src.unitKey][src.unitSetKey].Traits
    if not traitList then
        return
    end
    for index, boonKey in ipairs(traitList) do
        AddEntryBoon(entry, BuildBoonEntry(godKey, boonKey, index - 1))
    end
end

local function AddSpellBoons(entry, godKey)
    local spellNames = {}
    for spellName in pairs(SpellData) do
        spellNames[#spellNames + 1] = spellName
    end
    table.sort(spellNames)

    for index, spellName in ipairs(spellNames) do
        local spellData = SpellData[spellName]
        local displayName = spellData and spellData.TraitName and game.GetDisplayName({ Text = spellData.TraitName }) or spellName
        AddEntryBoon(entry, BuildBoonEntry(godKey, spellName, index - 1, displayName))
    end
end

local function AddWeaponUpgradeBoons(entry, godKey, meta)
    local traits = LootSetData.Loot and LootSetData.Loot.WeaponUpgrade and LootSetData.Loot.WeaponUpgrade.Traits
    if not traits then
        return
    end

    local prefixes = meta.prefixes or { godKey }
    local index = 0
    for _, trait in ipairs(traits) do
        local matches = false
        for _, prefix in ipairs(prefixes) do
            if string.find(trait, prefix, 1, true) == 1 then
                matches = true
                break
            end
        end
        if matches then
            AddEntryBoon(entry, BuildBoonEntry(godKey, trait, index))
            index = index + 1
        end
    end
end

local function AddMetaUpgradeBoons(entry, godKey, src)
    local dataSource = _G[src.dataSource]
    if not dataSource then
        return
    end

    local sortedKeys = {}
    local orderMap = {}
    if MetaUpgradeDefaultCardLayout then
        for _, row in ipairs(MetaUpgradeDefaultCardLayout) do
            for _, cardName in ipairs(row) do
                if dataSource[cardName] then
                    sortedKeys[#sortedKeys + 1] = cardName
                    orderMap[cardName] = true
                end
            end
        end
    end

    local remaining = {}
    for cardName in pairs(dataSource) do
        if not orderMap[cardName] then
            remaining[#remaining + 1] = cardName
        end
    end
    table.sort(remaining)
    for _, cardName in ipairs(remaining) do
        sortedKeys[#sortedKeys + 1] = cardName
    end

    local index = 0
    for _, upgradeName in ipairs(sortedKeys) do
        if not (src.exclude and src.exclude[upgradeName]) then
            local displayName = game.GetDisplayName({ Text = upgradeName })
            AddEntryBoon(entry, BuildBoonEntry(godKey, upgradeName, index, displayName))
            index = index + 1
        end
    end
end

function catalogExtractor.addSourceBoons(entry, godKey, meta)
    local src = meta and meta.lootSource or nil
    if not src then
        return
    end

    if src.type == "LootSet" then
        AddLootSetBoons(entry, godKey, meta, src)
    elseif src.type == "UnitSet" then
        AddUnitSetBoons(entry, godKey, src)
    elseif src.type == "SpellData" then
        AddSpellBoons(entry, godKey)
    elseif src.type == "WeaponUpgrade" then
        AddWeaponUpgradeBoons(entry, godKey, meta)
    elseif src.type == "MetaUpgrade" then
        AddMetaUpgradeBoons(entry, godKey, src)
    end
end

return catalogExtractor
