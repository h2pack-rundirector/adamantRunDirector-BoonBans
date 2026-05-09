---@meta _
---@diagnostic disable: lowercase-global

local internal = RunDirectorBoonBans_Internal

local SOURCE_FIELD = internal.BoonOfferSourceField or "RunDirectorBoonBans_OfferSourceName"
local PROBE_FIELD = "RunDirectorBoonBans_PersistenceProbe"
local PROBE_VERSION = "duo-source-v1"
local MODULE_ID = "BoonBans"
local probeState = internal.DuoSourcePersistenceProbeState or {}

internal.DuoSourcePersistenceProbeState = probeState

function internal.RegisterDuoSourcePersistenceProbeHooks(access)
    local function IsDebugEnabled()
        return access.read("DebugMode") == true
    end

    local function Log(fmt, ...)
        lib.logging.logIf(MODULE_ID, IsDebugEnabled(), fmt, ...)
    end

    local function IsDuoTraitName(traitName)
        return internal.IsDuoTraitName and internal.IsDuoTraitName(traitName) or false
    end

    local function ScanPersistedDuoSources(reason)
        if not IsDebugEnabled() then
            return false
        end
        if not CurrentRun or not CurrentRun.Hero or not CurrentRun.Hero.Traits then
            Log("[Probe] Duo source scan (%s): traits unavailable", tostring(reason))
            return false
        end

        local found = 0
        for _, trait in ipairs(CurrentRun.Hero.Traits) do
            if IsDuoTraitName(trait.Name) then
                found = found + 1
                Log(
                    "[Probe] Duo source scan (%s): trait=%s source=%s probe=%s id=%s",
                    tostring(reason),
                    tostring(trait.Name),
                    tostring(trait[SOURCE_FIELD]),
                    tostring(trait[PROBE_FIELD]),
                    tostring(trait.Id)
                )
            end
        end

        if found == 0 then
            Log("[Probe] Duo source scan (%s): no duo traits found", tostring(reason))
        end
        return true
    end

    internal.ScanDuoSourcePersistenceProbe = ScanPersistedDuoSources

    local function TryLateScan(reason)
        if not IsDebugEnabled() or not CurrentRun then
            return
        end

        if probeState.lastRun ~= CurrentRun then
            probeState.lastRun = CurrentRun
            probeState.didLateScan = false
        end

        if probeState.didLateScan then
            return
        end

        probeState.didLateScan = ScanPersistedDuoSources(reason) == true
    end

    lib.hooks.Wrap(internal, "CreateUpgradeChoiceButton", "duo-source-persistence-probe", function(base, screen, lootData, itemIndex, itemData, args)
        local button = base(screen, lootData, itemIndex, itemData, args)
        if IsDebugEnabled() and button and button.Data and lootData and lootData.Name and IsDuoTraitName(button.Data.Name) then
            button.Data[PROBE_FIELD] = PROBE_VERSION
            Log("[Probe] Stamped duo offer: trait=%s source=%s", tostring(button.Data.Name), tostring(button.Data[SOURCE_FIELD]))
        end
        return button
    end)

    lib.hooks.Wrap(internal, "AddTraitToHero", "duo-source-persistence-probe", function(base, args)
        local trait = base(args)
        if IsDebugEnabled() and trait and IsDuoTraitName(trait.Name) then
            Log(
                "[Probe] Added duo trait: trait=%s source=%s probe=%s id=%s",
                tostring(trait.Name),
                tostring(trait[SOURCE_FIELD]),
                tostring(trait[PROBE_FIELD]),
                tostring(trait.Id)
            )
        end
        return trait
    end)

    lib.hooks.Wrap(internal, "UpdateHeroTraitDictionary", "duo-source-persistence-probe", function(base, ...)
        local result = base(...)
        TryLateScan("UpdateHeroTraitDictionary")
        return result
    end)

    lib.hooks.Wrap(internal, "LoadMap", "duo-source-persistence-probe", function(base, args)
        local result = base(args)
        TryLateScan("LoadMap")
        return result
    end)

    ScanPersistedDuoSources("hook-register")
end

