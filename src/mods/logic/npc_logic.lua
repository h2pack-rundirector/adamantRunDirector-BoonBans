---@meta _
---@diagnostic disable: lowercase-global
local banConfig = nil
local godCatalog = nil

local band = bit32.band
local t_insert = table.insert

local module = {}

function module.bind(data)
    banConfig = data.banConfig
    godCatalog = data.catalog.entries
    return module
end

function module.registerHooks(host, store, banResolver)
    host.hooks.wrap("CirceRemoveShrineUpgrades", function(base, args)
        if not host.isEnabled() then return base(args) end
        local restores = {}
        if godCatalog["CirceBNB"] then
            local banMask = banConfig.GetBanMask("CirceBNB", store)
            for _, vow in ipairs(godCatalog["CirceBNB"].boons) do
                local name = vow.Key
                local isBanned = band(banMask, vow.Mask) ~= 0
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

    host.hooks.wrap("CirceRandomMetaUpgrade", function(base, args)
        if not host.isEnabled() then return base(args) end
        local restores = {}
        local metaState = GameState.MetaUpgradeState or {}
        if godCatalog["CirceCRD"] then
            local banMask = banConfig.GetBanMask("CirceCRD", store)
            for _, card in ipairs(godCatalog["CirceCRD"].boons) do
                local name = card.Key
                local isBanned = band(banMask, card.Mask) ~= 0
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

    host.hooks.wrap("AddRandomMetaUpgrades", function(base, numCards, args)
        if not host.isEnabled() then return base(numCards, args) end
        if numCards and numCards ~= GetTotalHeroTraitValue("PostBossCards") then return base(numCards, args) end

        local restores = {}
        local metaState = GameState.MetaUpgradeState or {}
        local currentBiome = CurrentRun.ClearedBiomes or 0
        local judgementKey = "Judgement" .. tostring(math.min(currentBiome, 3))
        if godCatalog[judgementKey] then
            local banMask = banConfig.GetBanMask(judgementKey, store)
            for _, card in ipairs(godCatalog[judgementKey].boons) do
                local name = card.Key
                local isBanned = band(banMask, card.Mask) ~= 0
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
        host.hooks.wrap(funcName, function(base, source, args, screen)
            if host.isEnabled() and args.UpgradeOptions then
                local allowed = {}
                local banned = {}
                local configCache = {}

                for _, option in ipairs(args.UpgradeOptions) do
                    if option.GameStateRequirements == nil or IsGameStateEligible(source, option.GameStateRequirements) then
                        local isBanned = banResolver.isTraitBanned(option.ItemName, {
                            cache = configCache,
                        })

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

    host.hooks.wrap("GetEligibleSpells", function(base, screen, args)
        local eligible = base(screen, args)
        if not host.isEnabled() then return eligible end

        local allowed = {}
        local banned = {}
        local configCache = {}

        for _, spellName in ipairs(eligible) do
            local isBanned = banResolver.isTraitBanned(spellName, {
                cache = configCache,
            })

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

    local npcFunctions = {
        "ArachneCostumeChoice", "NarcissusBenefitChoice", "EchoChoice",
        "MedeaCurseChoice", "CirceBlessingChoice", "IcarusBenefitChoice",
    }
    for _, func in ipairs(npcFunctions) do
        wrapNPCChoice(func)
    end
end

return module
