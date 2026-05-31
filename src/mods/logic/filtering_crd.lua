---@meta _
---@diagnostic disable: lowercase-global

local deps = ...
local moduleRef = deps.module
local traitInfo = deps.traitInfo

moduleRef.hooks.wrap("CirceRandomMetaUpgrade", function(host, runtime, base, args)
    if not host.isEnabled() then return base(args) end
    local restores = {}
    local metaState = GameState.MetaUpgradeState or {}
    local source = traitInfo.redCitrineDivination(runtime)
    if source ~= nil then
        source:forEachBanned(1, function(name)
            if metaState[name] and not metaState[name].Equipped then
                metaState[name].Equipped = true
                restores[name] = true
            end
        end)
    end
    base(args)
    for name, _ in pairs(restores) do
        metaState[name].Equipped = false
    end
end)
