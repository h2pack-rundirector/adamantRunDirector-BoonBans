-- luacheck: no unused args

local band = bit32.band

local runtime = {}

local RARITY_BY_VALUE = { [1] = "Common", [2] = "Rare", [3] = "Epic" }

function runtime.create(fields, instance)
    local control = {}

    function control:tierCount()
        return fields.Tiers:count()
    end

    function control:name()
        return instance.name
    end

    function control:group()
        return instance.group
    end

    function control:maxTiers()
        return instance.maxTiers
    end

    function control:defaultTiers()
        return instance.defaultTiers
    end

    function control:hasRarity()
        return instance.hasRarity == true
    end

    function control:hasBridalGlowTargets()
        return #instance.bridalGlowTargets > 0
    end

    function control:color()
        return instance.color
    end

    function control:label()
        return instance.label or instance.name
    end

    function control:tierKey(tierIndex)
        tierIndex = math.floor(tonumber(tierIndex) or 1)
        if tierIndex <= 1 then
            return instance.name
        end
        return instance.name .. tostring(tierIndex)
    end

    function control:isTierConfigured(tierIndex)
        tierIndex = math.floor(tonumber(tierIndex) or 1)
        return tierIndex >= 1 and tierIndex <= self:tierCount()
    end

    function control:banMask(tierIndex)
        if not self:isTierConfigured(tierIndex) then
            return 0
        end
        return band(fields.Tiers:read(tierIndex, "Bans") or 0, instance.fullMask)
    end

    function control:isBanned(traitKey, tierIndex)
        local item = instance.itemByKey[traitKey]
        return item ~= nil and band(self:banMask(tierIndex), item.mask) ~= 0
    end

    function control:forEachBanned(tierIndex, callback)
        local banMask = self:banMask(tierIndex)
        if banMask == 0 then
            return
        end

        for _, item in ipairs(instance.items) do
            if band(banMask, item.mask) ~= 0 then
                callback(item.key, item)
            end
        end
    end

    function control:rarityValue(traitKey)
        if fields.Rarity == nil then
            return 0
        end
        local item = instance.itemByKey[traitKey]
        return item and math.floor(tonumber(fields.Rarity:readAlias(item.key)) or 0) or 0
    end

    function control:rarityValueAtBit(bitIndex)
        local item = instance.itemByBit[math.floor(tonumber(bitIndex) or -1)]
        return item and self:rarityValue(item.key) or 0
    end

    function control:rarityOverride(traitKey)
        return RARITY_BY_VALUE[self:rarityValue(traitKey)]
    end

    function control:collectBridalGlowTargets(out)
        out = out or {}
        for _, target in ipairs(instance.bridalGlowTargets) do
            out[#out + 1] = target
        end
        return out
    end

    function control:findBridalGlowTarget(traitKey)
        return instance.bridalGlowTargetByKey[traitKey]
    end

    function control:isTierCustomized(tierIndex)
        return self:banMask(tierIndex) ~= 0
    end

    function control:isCustomized()
        for tierIndex = 1, self:tierCount() do
            if self:isTierCustomized(tierIndex) then
                return true
            end
        end
        return false
    end

    function control:read(path, ...)
        if path == "tierCount" then
            return self:tierCount()
        elseif path == "banMask" then
            return self:banMask(...)
        elseif path == "rarity" then
            return self:rarityValue(...)
        end
        return nil
    end

    return control
end

return runtime
