---@meta _
---@diagnostic disable: lowercase-global

local deps = ...
local moduleRef = deps.module
local traitInfo = deps.traitInfo

moduleRef.hooks.wrap("AddRandomMetaUpgrades", function(host, runtime, base, numCards, args)
    if not host.isEnabled() then return base(numCards, args) end
    if numCards and numCards ~= GetTotalHeroTraitValue("PostBossCards") then return base(numCards, args) end

    local restores = {}
    local metaState = GameState.MetaUpgradeState or {}
    local currentBiome = CurrentRun.ClearedBiomes or 0
    local source = traitInfo.judgement(runtime, currentBiome)
    if source ~= nil then
        source:forEachBanned(1, function(name)
            if metaState[name] and not metaState[name].Equipped then
                metaState[name].Equipped = true
                restores[name] = true
            end
        end)
    end
    base(numCards, args)
    for name, _ in pairs(restores) do
        metaState[name].Equipped = false
    end
end)
