---@meta _
---@diagnostic disable: lowercase-global
local deps = ...
local moduleRef = deps.module
local runState = deps.runState
local traitInfo = deps.traitInfo

local ACTIVE_GOD = "activeGod"
local OFFER_SOURCES = "offerSources"

local function IsDuoTraitName(traitName)
    local traitData = traitName and TraitData[traitName]
    return traitData and traitData.IsDuoBoon == true
end

local function PrimarySourceNameFromLoot(sourceName)
    if type(sourceName) ~= "string" or sourceName == "" then
        return nil
    end

    local info = traitInfo.lookupLoot(sourceName)
    local godKey = info and info.controlName or nil
    if not godKey then
        return nil
    end

    return traitInfo.primarySourceName(godKey)
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

local function ResolveAcquiredGodKey(args, traitData, acquiredTrait)
    local traitName = GetAcquiredTraitName(args, traitData, acquiredTrait)

    local rememberedSourceName = runState and runState.scratch.mapGet(OFFER_SOURCES, traitName) or nil
    local rememberedGodKey = PrimarySourceNameFromLoot(rememberedSourceName)
    if rememberedGodKey then
        return rememberedGodKey, "remembered-source"
    end

    local argsGodKey = PrimarySourceNameFromLoot(args and args.SourceName or nil)
    if argsGodKey then
        return argsGodKey, "args-source"
    end

    local activeGodKey = runState and runState.scratch.get(ACTIVE_GOD) or nil
    if activeGodKey then
        return traitInfo.primarySourceName(activeGodKey), "active-god"
    end

    if traitName and not IsDuoTraitName(traitName) then
        local info = traitInfo.lookupTrait(traitName)
        if info then
            return info.controlName, "source-resolver"
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

moduleRef.hooks.wrap("CreateUpgradeChoiceButton", "live-boon-offer-source", function(
    runtimeHost, _, base, screen, lootData, itemIndex, itemData, args
)
    local button = base(screen, lootData, itemIndex, itemData, args)

    if runtimeHost.isEnabled()
        and button and button.Data
        and lootData and lootData.Name
        and IsDuoTraitName(button.Data.Name) then
        runState.scratch.mapSet(OFFER_SOURCES, button.Data.Name, lootData.Name)
    end

    return button
end)

moduleRef.hooks.wrap("OpenUpgradeChoiceMenu", function(host, _, base, source, args)
    runState.scratch.clear(OFFER_SOURCES)
    if host.isEnabled() and source and source.Name then
        local info = traitInfo.lookupLoot(source.Name)
        runState.scratch.set(ACTIVE_GOD, info and info.controlName or nil)
    end
    base(source, args)
end)

moduleRef.hooks.wrap("AddTraitToHero", function(host, runtime, base, args)
    local result = base(args)
    local traitData = args and args.TraitData or result

    if host.isEnabled() and runState.hasCurrentRun(runtime) and traitData then
        local traitName = GetAcquiredTraitName(args, traitData, result)
        local godKey, sourceMode = ResolveAcquiredGodKey(args, traitData, result)
        local shouldAdvance, advanceMode = ShouldAdvanceBanPool(args, traitData, result, godKey)

        host.logIf(
            "[Micro] AddTraitToHero: trait=%s god=%s source=%s progression=%s",
            tostring(traitName),
            tostring(godKey),
            tostring(sourceMode),
            tostring(advanceMode)
        )

        if shouldAdvance then
            local newCount = runState.recordAcquisition(runtime, godKey)
            host.logIf("[Micro] AddTraitToHero: %s. God: %s. New Count: %d", tostring(traitName), tostring(godKey),
                newCount or 0)
        end
        runState.scratch.clear(ACTIVE_GOD)

        if shouldAdvance then
            runState.consumeForcedRarity(runtime, traitName)
        end
    end
    return result
end)
