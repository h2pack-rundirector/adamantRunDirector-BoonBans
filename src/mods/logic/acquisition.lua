---@meta _
---@diagnostic disable: lowercase-global

local internal = RunDirectorBoonBans_Internal
local banConfig = internal.banConfig

local ACTIVE_GOD = "activeGod"
local OFFER_SOURCES = "offerSources"

local function IsDuoTraitName(traitName)
    local traitData = traitName and TraitData[traitName]
    return traitData and traitData.IsDuoBoon == true
end

local function ResolveGodKeyFromSourceName(sourceName, banResolver)
    if type(sourceName) ~= "string" or sourceName == "" then
        return nil
    end

    local godKey = banResolver.getGodFromLootsource(sourceName)
    if not godKey then
        return nil
    end

    return banConfig.ResolveGodKey(godKey)
end

local function GetAcquiredTraitName(args, traitData, acquiredTrait)
    if acquiredTrait and acquiredTrait.Name then
        return acquiredTrait.Name
    end
    if traitData and traitData.Name then
        return traitData.Name
    end
    return args and args.TraitName or nil
end

local function ResolveAcquiredGodKey(args, traitData, acquiredTrait, runState, banResolver)
    local traitName = GetAcquiredTraitName(args, traitData, acquiredTrait)

    local rememberedSourceName = runState and runState.scratch.mapGet(OFFER_SOURCES, traitName) or nil
    local rememberedGodKey = ResolveGodKeyFromSourceName(rememberedSourceName, banResolver)
    if rememberedGodKey then
        return rememberedGodKey, "remembered-source"
    end

    local argsGodKey = ResolveGodKeyFromSourceName(args and args.SourceName or nil, banResolver)
    if argsGodKey then
        return argsGodKey, "args-source"
    end

    local activeGodKey = runState and runState.scratch.get(ACTIVE_GOD) or nil
    if activeGodKey then
        return banConfig.ResolveGodKey(activeGodKey), "active-god"
    end

    if traitName and not IsDuoTraitName(traitName) then
        local godKey = banResolver.getTraitGodKey(traitName)
        if godKey then
            return godKey, "catalog"
        end
    end

    return nil, "unresolved"
end

local function ShouldAdvanceBanPool(args, traitData, acquiredTrait, godKey)
    local traitName = GetAcquiredTraitName(args, traitData, acquiredTrait)

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

function internal.RegisterAcquisitionHooks(host, runState, banResolver)
    lib.hooks.Wrap(internal, "CreateUpgradeChoiceButton", "live-boon-offer-source", function(base, screen, lootData, itemIndex, itemData, args)
        local button = base(screen, lootData, itemIndex, itemData, args)

        if host.isEnabled()
            and button and button.Data
            and lootData and lootData.Name
            and IsDuoTraitName(button.Data.Name) then
            runState.scratch.mapSet(OFFER_SOURCES, button.Data.Name, lootData.Name)
        end

        return button
    end)

    lib.hooks.Wrap(internal, "OpenUpgradeChoiceMenu", function(base, source, args)
        runState.scratch.clear(OFFER_SOURCES)
        if host.isEnabled() and source and source.Name then
            runState.scratch.set(ACTIVE_GOD, banResolver.getGodFromLootsource(source.Name))
        end
        base(source, args)
    end)

    lib.hooks.Wrap(internal, "AddTraitToHero", function(base, args)
        local result = base(args)
        local traitData = args and args.TraitData or result

        if host.isEnabled() and runState.hasCurrentRun() and traitData then
            local traitName = GetAcquiredTraitName(args, traitData, result)
            local godKey, sourceMode = ResolveAcquiredGodKey(args, traitData, result, runState, banResolver)
            local shouldAdvance, advanceMode = ShouldAdvanceBanPool(args, traitData, result, godKey)

            host.logIf(
                "[Micro] AddTraitToHero: trait=%s god=%s source=%s progression=%s",
                tostring(traitName),
                tostring(godKey),
                tostring(sourceMode),
                tostring(advanceMode)
            )

            if shouldAdvance then
                local newCount = runState.recordAcquisition(godKey)
                host.logIf("[Micro] AddTraitToHero: %s. God: %s. New Count: %d", tostring(traitName), tostring(godKey),
                    newCount or 0)
            end
            runState.scratch.clear(ACTIVE_GOD)

            if shouldAdvance then
                runState.consumeForcedRarity(traitName)
            end
        end
        return result
    end)
end
