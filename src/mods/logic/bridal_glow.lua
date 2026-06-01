---@meta _
---@diagnostic disable: lowercase-global

local deps = ...
local moduleRef = deps.module

moduleRef.hooks.wrap("HeraSuperchargeBoon", function(host, runtime, base, args, origTraitData, contextArgs)
    if not host.isEnabled() then
        return base(args, origTraitData, contextArgs)
    end

    local targetBoon = runtime.data.get("BridalGlowTargetBoon"):read()
    if not targetBoon or targetBoon == "" then
        return base(args, origTraitData, contextArgs)
    end

    local targetTrait = GetHeroTrait(targetBoon)
    if not targetTrait or targetTrait.BlockStacking == true then
        return base(args, origTraitData, contextArgs)
    end

    contextArgs = contextArgs or {}

    local traitData = AddRarityToTraits(targetTrait, {
        ForceUpgrade = { targetTrait },
        TargetRarity = 4,
        Silent = true,
    })

    if not traitData then
        return base(args, origTraitData, contextArgs)
    end

    thread(AddStackToTraits, { TraitName = traitData.Name, NumStacks = args.Stacks, Silent = true })
    IncreaseTraitLevel(traitData, args.Stacks)

    origTraitData.UpgradedTraitName = traitData.Name
    thread(HeraTraitRarityPresentation, traitData.Name, args.Stacks, contextArgs.Delay)
end)
