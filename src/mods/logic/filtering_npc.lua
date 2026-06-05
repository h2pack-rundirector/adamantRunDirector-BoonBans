---@meta _
---@diagnostic disable: lowercase-global

local t_insert = table.insert

local deps = ...
local moduleRef = deps.module
local traitInfo = deps.traitInfo
local padding = deps.padding

local function wrapNPCChoice(funcName)
    moduleRef.hooks.wrap(funcName, function(host, runtime, base, source, args, screen)
        if host.isEnabled() and args.UpgradeOptions then
            local allowed = {}
            local banned = {}

            for _, option in ipairs(args.UpgradeOptions) do
                if option.GameStateRequirements == nil or IsGameStateEligible(source, option.GameStateRequirements) then
                    local isBanned = traitInfo.isBanned(option.ItemName, runtime)

                    if not isBanned then
                        t_insert(allowed, option)
                    else
                        t_insert(banned, option)
                    end
                end
            end

            if padding then
                padding.extendChoiceList(allowed, banned, {
                    config = padding.readConfig(runtime),
                    maxSize = GetTotalLootChoices(),
                    force = funcName == "CirceBlessingChoice",
                })
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

local npcFunctions = {
    "ArachneCostumeChoice", "NarcissusBenefitChoice", "EchoChoice",
    "MedeaCurseChoice", "CirceBlessingChoice", "IcarusBenefitChoice",
}
for _, func in ipairs(npcFunctions) do
    wrapNPCChoice(func)
end
