---@meta _
---@diagnostic disable: lowercase-global

local deps = ...
local moduleRef = deps.module

moduleRef.hooks.wrap("CirceRemoveShrineUpgrades", function(host, runtime, base, args)
    if not host.isEnabled() then return base(args) end
    local restores = {}
    local source = runtime.controls.get("CirceBNB")
    if source ~= nil then
        source:forEachBanned(1, function(name)
            if MetaUpgradeData[name] then
                restores[name] = MetaUpgradeData[name].IneligibleForCirceRemoval
                MetaUpgradeData[name].IneligibleForCirceRemoval = true
            end
        end)
    end
    base(args)
    for name, value in pairs(restores) do
        MetaUpgradeData[name].IneligibleForCirceRemoval = value
    end
end)
