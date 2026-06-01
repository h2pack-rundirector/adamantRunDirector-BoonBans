local declarations = {}

local function cloneColor(color)
    if type(color) ~= "table" then
        return nil
    end
    return { color[1], color[2], color[3], color[4] }
end

local function buildItems(entry, showValueColors)
    local items = {}
    for _, boon in ipairs(entry and entry.boons or {}) do
        items[#items + 1] = {
            key = boon.Key,
            label = boon.Name,
            displayLabel = boon.SpecialDisplayLabel or boon.Name or boon.Key,
            searchText = boon.NameLower or tostring(boon.Name or boon.Key or ""):lower(),
            bit = boon.Bit,
            mask = boon.Mask,
            isRarityEligible = boon.IsRarityEligible ~= false,
            isBridalGlowEligible = boon.IsBridalGlowEligible == true,
            valueColor = showValueColors == false and nil or cloneColor(boon.SpecialBadgeColor),
        }
    end
    return items
end

local function getMaxTiers(def)
    return def and def.maxBanPools or 1
end

local function getDefaultTiers(def)
    return def and def.defaultBanPools or 1
end

local function isControlOwner(godKey, def)
    return def
        and (def.banPoolGroupKey or godKey) == godKey
        and (def.banPoolIndex or 1) == 1
end

local function isRequiredControl(def)
    return def and def.lootSource ~= nil and def.allowEmptyControl ~= true
end

local function describeLootSource(def)
    local src = def and def.lootSource or nil
    if src == nil then
        return "unknown source"
    end
    if src.type == "LootSet" then
        return "LootSet " .. tostring(src.key or def.key)
    end
    if src.type == "UnitSet" then
        return "UnitSet " .. tostring(src.unitKey) .. "/" .. tostring(src.unitSetKey)
    end
    if src.type == "WeaponUpgrade" then
        return "WeaponUpgrade " .. tostring(src.key or def.key)
    end
    if src.type == "MetaUpgrade" then
        return "MetaUpgrade " .. tostring(src.dataSource or def.key)
    end
    if src.type == "Keepsake" then
        return "Keepsake " .. tostring(src.key or def.key)
    end
    return tostring(src.type or "unknown source")
end

local function requireControlItems(godKey, def, items)
    if #items > 0 or not isRequiredControl(def) then
        return
    end

    error(string.format(
        "BoonBans data error: required control %s produced no traits from %s; game-data extraction failed.",
        tostring(godKey),
        describeLootSource(def)
    ), 0)
end

local function getDisplayLabel(godKey, def)
    local display = def and def.displayTextKey or godKey
    if getMaxTiers(def) > 1 then
        display = display:gsub("^1st%s+", "")
    end
    return display
end

function declarations.build(godDefs, catalog)
    local controls = {}
    local entries = catalog and catalog.entries or {}
    local keys = {}

    for godKey, def in pairs(godDefs or {}) do
        if isControlOwner(godKey, def) then
            keys[#keys + 1] = godKey
        end
    end
    table.sort(keys)

    for _, godKey in ipairs(keys) do
        local def = godDefs[godKey]
        local entry = entries[godKey]
        local items = buildItems(entry, def and def.showPackedValueColors)
        requireControlItems(godKey, def, items)
        if #items > 0 then
            controls[godKey] = {
                template = "TraitSource",
                label = getDisplayLabel(godKey, def),
                color = entry and cloneColor(entry.color) or nil,
                group = def and def.uiGroup or nil,
                items = items,
                maxTiers = getMaxTiers(def),
                defaultTiers = getDefaultTiers(def),
                hasRarity = def and def.hasRarity == true,
                showValueColors = not (def and def.showPackedValueColors == false),
            }
        end
    end

    return controls
end

return declarations
