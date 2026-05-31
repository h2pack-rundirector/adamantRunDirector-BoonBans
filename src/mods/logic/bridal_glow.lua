---@meta _
---@diagnostic disable: lowercase-global

local deps = ...
local moduleRef = deps.module

moduleRef.hooks.wrap("HeraSuperchargeBoon", function(_, runtime, base, args, origTraitData, contextArgs)
    local targetBoon = runtime.data.get("BridalGlowTargetBoon"):read()
    if not targetBoon or targetBoon == "" then
        base(args, origTraitData, contextArgs)
        return
    end

    local targetTrait = GetHeroTrait(targetBoon)
    if not targetTrait or targetTrait.BlockStacking == true then
        base(args, origTraitData, contextArgs)
        return
    end

    contextArgs = contextArgs or {}

    local traitData = AddRarityToTraits(targetTrait, {
        ForceUpgrade = { targetTrait },
        TargetRarity = 4,
        Silent = true,
    })

    if not traitData then
        base(args, origTraitData, contextArgs)
        return
    end

    thread(AddStackToTraits, { TraitName = traitData.Name, NumStacks = args.Stacks, Silent = true })
    IncreaseTraitLevel(traitData, args.Stacks)

    origTraitData.UpgradedTraitName = traitData.Name
    thread(HeraTraitRarityPresentation, traitData.Name, args.Stacks, contextArgs.Delay)
end)
