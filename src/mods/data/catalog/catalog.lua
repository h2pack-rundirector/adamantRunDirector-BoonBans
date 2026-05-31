---@meta _
---@diagnostic disable: lowercase-global

local extractor = import("mods/data/catalog/catalog_extractor.lua")

local catalogModule = {}
local t_insert = table.insert

local function BuildCatalogEntry()
    return {
        boons = {},
        boonByKey = {},
    }
end

local function AddBoonToEntry(entry, boon)
    entry.boons[#entry.boons + 1] = boon
    entry.boonByKey[boon.Key] = boon
end

local function GetGodColor(godDefs, name)
    local meta = godDefs[name]
    local colorKey = meta and meta.colorKey
    local inGameColor = colorKey and game.Color[colorKey] or game.Color.Black
    return { inGameColor[1] / 255, inGameColor[2] / 255, inGameColor[3] / 255, inGameColor[4] / 255 }
end

function catalogModule.buildBase(godDefs)
    local baseCatalog = {}
    for godKey, def in pairs(godDefs) do
        if not def.duplicateOf and def.lootSource then
            local entry = BuildCatalogEntry()
            extractor.addSourceBoons(entry, godKey, def)
            baseCatalog[godKey] = entry
        end
    end
    return baseCatalog
end

function catalogModule.build(godDefs, baseCatalog)
    local catalog = {
        base = baseCatalog,
        entries = {},
        traitLookup = {},
    }

    local function addBoonToCatalog(godKey, sourceBoon)
        local entry = catalog.entries[godKey]
        if not entry then
            return
        end

        local boon = {}
        for key, value in pairs(sourceBoon) do
            boon[key] = value
        end
        boon.God = godKey
        AddBoonToEntry(entry, boon)

        local lookupEntry = { god = godKey, bit = boon.Bit, mask = boon.Mask }
        if not catalog.traitLookup[boon.Key] then
            catalog.traitLookup[boon.Key] = { lookupEntry }
        else
            t_insert(catalog.traitLookup[boon.Key], lookupEntry)
        end
    end

    for godKey in pairs(godDefs) do
        catalog.entries[godKey] = {
            color = GetGodColor(godDefs, godKey),
            boons = {},
            boonByKey = {},
        }
    end

    for godKey, def in pairs(godDefs) do
        if not def.duplicateOf and def.lootSource then
            local baseEntry = baseCatalog[godKey]
            if baseEntry and baseEntry.boons then
                for _, boon in ipairs(baseEntry.boons) do
                    addBoonToCatalog(godKey, boon)
                end
            end
        end
    end

    for godKey, def in pairs(godDefs) do
        if def.duplicateOf then
            local parentEntry = catalog.entries[def.duplicateOf]
            if parentEntry then
                for _, parentBoon in ipairs(parentEntry.boons) do
                    addBoonToCatalog(godKey, parentBoon)
                end
            end
        end
    end

    return catalog
end

return catalogModule
