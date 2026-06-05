---@meta _
---@diagnostic disable: lowercase-global

local t_insert = table.insert

local deps = ...
local moduleRef = deps.module
local traitInfo = deps.traitInfo
local padding = deps.padding

moduleRef.hooks.wrap("GetEligibleSpells", function(host, runtime, base, screen, args)
    local eligible = base(screen, args)
    if not host.isEnabled() then return eligible end

    local allowed = {}
    local banned = {}

    for _, spellName in ipairs(eligible) do
        local isBanned = traitInfo.isBanned(spellName, runtime)

        if not isBanned then
            t_insert(allowed, spellName)
        else
            t_insert(banned, spellName)
        end
    end

    host.logIf("[Micro] GetEligibleSpells: Allowed %d, Banned %d", #allowed, #banned)

    if #allowed == 0 then return eligible end

    if padding then
        padding.extendChoiceList(allowed, banned, {
            config = padding.readConfig(runtime),
            maxSize = GetTotalLootChoices(),
        })
    end

    return allowed
end)
