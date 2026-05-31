local deps = ...
local moduleRef = deps.module
local runState = deps.runState

moduleRef.hooks.wrap("GetRarityChances", function(host, runtime, base, loot)
    local chances = base(loot)
    if host.isEnabled() and runState.shouldForceRarity(runtime, loot) then
        chances.Common, chances.Rare, chances.Epic = 0.0, 0.0, 1.0
    end
    return chances
end)
