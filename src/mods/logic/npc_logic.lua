---@meta _
---@diagnostic disable: lowercase-global

local internal = RunDirectorBoonBans_Internal
local banConfigView = internal.banConfigView
local godInfo = internal.godInfo

local band = bit32.band
local t_insert = table.insert

function internal.RegisterNpcHooks(host, store)
    local function GetRunState()
        return internal.runtimeUtilities.GetRunState(store)
    end

    lib.hooks.Wrap(internal, "CirceRemoveShrineUpgrades", function(base, args)
        if not host.isEnabled() then return base(args) end
        local restores = {}
        if godInfo["CirceBNB"] then
            local configVal = banConfigView.GetBanConfig("CirceBNB", store)
            for _, vow in ipairs(godInfo["CirceBNB"].boons) do
                local name = vow.Key
                local isBanned = band(configVal, vow.Mask) ~= 0
                if MetaUpgradeData[name] and isBanned then
                    restores[name] = MetaUpgradeData[name].IneligibleForCirceRemoval
                    MetaUpgradeData[name].IneligibleForCirceRemoval = true
                end
            end
        end
        base(args)
        for name, value in pairs(restores) do
            MetaUpgradeData[name].IneligibleForCirceRemoval = value
        end
    end)

    lib.hooks.Wrap(internal, "CirceRandomMetaUpgrade", function(base, args)
        if not host.isEnabled() then return base(args) end
        local restores = {}
        local metaState = GameState.MetaUpgradeState or {}
        if godInfo["CirceCRD"] then
            local configVal = banConfigView.GetBanConfig("CirceCRD", store)
            for _, card in ipairs(godInfo["CirceCRD"].boons) do
                local name = card.Key
                local isBanned = band(configVal, card.Mask) ~= 0
                if metaState[name] and not metaState[name].Equipped and isBanned then
                    metaState[name].Equipped = true
                    restores[name] = true
                end
            end
        end
        base(args)
        for name, _ in pairs(restores) do
            metaState[name].Equipped = false
        end
    end)

    lib.hooks.Wrap(internal, "AddRandomMetaUpgrades", function(base, numCards, args)
        if not host.isEnabled() then return base(numCards, args) end
        if numCards and numCards ~= GetTotalHeroTraitValue("PostBossCards") then return base(numCards, args) end

        local restores = {}
        local metaState = GameState.MetaUpgradeState or {}
        local currentBiome = CurrentRun.ClearedBiomes or 0
        local judgementKey = "Judgement" .. tostring(math.min(currentBiome, 3))
        if godInfo[judgementKey] then
            local configVal = banConfigView.GetBanConfig(judgementKey, store)
            for _, card in ipairs(godInfo[judgementKey].boons) do
                local name = card.Key
                local isBanned = band(configVal, card.Mask) ~= 0
                if metaState[name] and not metaState[name].Equipped and isBanned then
                    metaState[name].Equipped = true
                    restores[name] = true
                end
            end
        end
        base(numCards, args)
        for name, _ in pairs(restores) do
            metaState[name].Equipped = false
        end
    end)

    local function wrapNPCChoice(funcName)
        lib.hooks.Wrap(internal, funcName, function(base, source, args, screen)
            if host.isEnabled() and args.UpgradeOptions then
                local allowed = {}
                local banned = {}
                local configCache = {}

                for _, option in ipairs(args.UpgradeOptions) do
                    if option.GameStateRequirements == nil or IsGameStateEligible(source, option.GameStateRequirements) then
                        local info = internal.FindTraitInfo(option.ItemName, nil)
                        local isBanned = false
                        if info then
                            local cfg = configCache[info.god] or banConfigView.GetBanConfig(info.god, store)
                            configCache[info.god] = cfg
                            if band(cfg, info.mask) ~= 0 then
                                isBanned = true
                            end
                        end

                        if not isBanned then
                            t_insert(allowed, option)
                        else
                            t_insert(banned, option)
                        end
                    end
                end

                if #allowed > 0 then
                    args.UpgradeOptions = allowed
                end

                if #banned > 0 then
                    host.logIf("[Micro] NPC Choice (%s): Allowed %d, Banned %d", funcName, #allowed, #banned)
                end
            end
            return base(source, args, screen)
        end)
    end

    lib.hooks.Wrap(internal, "GetEligibleSpells", function(base, screen, args)
        local eligible = base(screen, args)
        if not host.isEnabled() then return eligible end

        local allowed = {}
        local banned = {}
        local configCache = {}

        for _, spellName in ipairs(eligible) do
            local info = internal.FindTraitInfo(spellName, nil)
            local isBanned = false
            if info then
                local cfg = configCache[info.god] or banConfigView.GetBanConfig(info.god, store)
                configCache[info.god] = cfg
                if band(cfg, info.mask) ~= 0 then
                    isBanned = true
                end
            end

            if not isBanned then
                t_insert(allowed, spellName)
            else
                t_insert(banned, spellName)
            end
        end

        host.logIf("[Micro] GetEligibleSpells: Allowed %d, Banned %d", #allowed, #banned)

        if #allowed == 0 then return eligible end

        return allowed
    end)

    lib.hooks.Wrap(internal, "OpenUpgradeChoiceMenu", function(base, source, args)
        if host.isEnabled() and source and source.Name then
            internal.ActiveGodKey = internal.GetGodFromLootsource(source.Name)
        end
        base(source, args)
    end)

    lib.hooks.Wrap(internal, "AddTraitToHero", function(base, args)
        local result = base(args)
        local traitData = args and args.TraitData or result
        local state = GetRunState()

        if host.isEnabled() and state and traitData then
            local traitName = internal.GetAcquiredTraitName(args, traitData, result)
            local godKey, sourceMode = internal.ResolveAcquiredGodKey(args, traitData, result)
            local shouldAdvance, advanceMode = internal.ShouldAdvanceBoonTier(args, traitData, result, godKey)

            host.logIf(
                "[Micro] AddTraitToHero: trait=%s god=%s source=%s progression=%s",
                tostring(traitName),
                tostring(godKey),
                tostring(sourceMode),
                tostring(advanceMode)
            )

            if shouldAdvance then
                state.BoonPickCounts[godKey] = (state.BoonPickCounts[godKey] or 0) + 1
                host.logIf("[Micro] AddTraitToHero: %s. God: %s. New Count: %d", tostring(traitName), tostring(godKey),
                    state.BoonPickCounts[godKey])
            end
            internal.ActiveGodKey = nil

            if shouldAdvance and CurrentRun and state.ImproveFirstNBoonRarity and IsGodTrait(traitName) then
                state.ImproveFirstNBoonRarity = math.max(0, state.ImproveFirstNBoonRarity - 1)
            end
        end
        return result
    end)

    lib.hooks.Wrap(internal, "GetRarityChances", function(base, loot)
        local chances = base(loot)
        local state = GetRunState()
        if host.isEnabled() and CurrentRun and state.ImproveFirstNBoonRarity > 0 and loot.GodLoot then
            chances.Common, chances.Rare, chances.Epic = 0.0, 0.0, 1.0
        end
        return chances
    end)

    local npcFunctions = {
        "ArachneCostumeChoice", "NarcissusBenefitChoice", "EchoChoice",
        "MedeaCurseChoice", "CirceBlessingChoice", "IcarusBenefitChoice",
    }
    for _, func in ipairs(npcFunctions) do
        wrapNPCChoice(func)
    end
end
