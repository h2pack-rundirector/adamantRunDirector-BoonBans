---@meta _
---@diagnostic disable: lowercase-global

local internal = RunDirectorBoonBans_Internal

local SOURCE_FIELD = internal.BoonOfferSourceField or "RunDirectorBoonBans_OfferSourceName"

internal.BoonOfferSourceField = SOURCE_FIELD

local function IsBoonBansActive()
    return internal.host.isEnabled()
end

function internal.IsDuoTraitName(traitName)
    local traitData = traitName and TraitData[traitName]
    return traitData and traitData.IsDuoBoon == true
end

function internal.GetAcquiredTraitName(args, traitData, acquiredTrait)
    if acquiredTrait and acquiredTrait.Name then
        return acquiredTrait.Name
    end
    if traitData and traitData.Name then
        return traitData.Name
    end
    return args and args.TraitName or nil
end

function internal.StampUpgradeOfferSource(upgradeData, sourceName)
    if type(upgradeData) ~= "table" or type(sourceName) ~= "string" or sourceName == "" then
        return false
    end
    upgradeData[SOURCE_FIELD] = sourceName
    return true
end

local function ResolveGodKeyFromSourceName(sourceName)
    if type(sourceName) ~= "string" or sourceName == "" then
        return nil
    end

    local godKey = internal.GetGodFromLootsource and internal.GetGodFromLootsource(sourceName) or nil
    if not godKey then
        return nil
    end

    return internal.GetRootKey and internal.GetRootKey(godKey) or godKey
end

function internal.ResolveAcquiredGodKey(args, traitData, acquiredTrait)
    local traitName = internal.GetAcquiredTraitName(args, traitData, acquiredTrait)

    local stampedSourceName = (acquiredTrait and acquiredTrait[SOURCE_FIELD])
        or (traitData and traitData[SOURCE_FIELD])
    local stampedGodKey = ResolveGodKeyFromSourceName(stampedSourceName)
    if stampedGodKey then
        return stampedGodKey, "stamped-source"
    end

    local argsGodKey = ResolveGodKeyFromSourceName(args and args.SourceName or nil)
    if argsGodKey then
        return argsGodKey, "args-source"
    end

    if internal.ActiveGodKey then
        return internal.GetRootKey(internal.ActiveGodKey), "active-god"
    end

    if traitName and not internal.IsDuoTraitName(traitName) and internal.FindTraitInfo then
        local info = internal.FindTraitInfo(traitName, nil)
        if info then
            return internal.GetRootKey(info.god), "catalog"
        end
    end

    return nil, "unresolved"
end

function internal.ShouldAdvanceBoonTier(args, traitData, acquiredTrait, godKey)
    local traitName = internal.GetAcquiredTraitName(args, traitData, acquiredTrait)

    if not godKey then
        return false, "no-god-key"
    end
    if not traitName then
        return false, "no-trait-name"
    end
    if not args or args.FromLoot ~= true then
        return false, "not-from-loot"
    end
    if args.SkipSetup then
        return false, "skip-setup"
    end
    if args.SkipActivatedTraitUpdate then
        return false, "skip-activated-update"
    end
    if args.SkipNewTraitHighlight then
        return false, "skip-new-trait-highlight"
    end

    return true, "counted"
end

lib.hooks.Wrap(internal, "CreateUpgradeChoiceButton", "live-boon-offer-source", function(base, screen, lootData, itemIndex, itemData, args)
    local button = base(screen, lootData, itemIndex, itemData, args)

    if IsBoonBansActive()
        and button and button.Data
        and lootData and lootData.Name
        and internal.IsDuoTraitName(button.Data.Name) then
        internal.StampUpgradeOfferSource(button.Data, lootData.Name)
    end

    return button
end)
