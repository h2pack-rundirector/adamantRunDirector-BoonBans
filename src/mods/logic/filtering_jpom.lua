local deps = ...
local moduleRef = deps.module
local context = deps.context

moduleRef.hooks.wrap("GiveRandomHadesBoonAndBoostBoons", function(_, _, base, args)
    context.isJpomOffering = true
    local result = base(args)
    context.isJpomOffering = false
    return result
end)
