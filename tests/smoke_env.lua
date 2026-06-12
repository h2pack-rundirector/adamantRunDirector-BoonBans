-- luacheck: no unused args

local function addLootSetSource(lootSetData, sourceName, upgradeName, traitName)
    lootSetData[sourceName] = {
        [upgradeName] = {
            Traits = { traitName },
        },
    }
end

local function addUnitSetSource(unitSetData, unitKey, unitSetKey, traitName)
    unitSetData[unitKey] = {
        [unitSetKey] = {
            Traits = { traitName },
        },
    }
end

local function configureBoonBansGameData(env)
    local lootSetData = {
        Loot = {
            WeaponUpgrade = {
                Traits = {
                    "StaffTestTrait",
                    "DaggerTestTrait",
                    "AxeTestTrait",
                    "TorchTestTrait",
                    "LobTestTrait",
                    "SuitTestTrait",
                },
            },
        },
    }

    for _, godKey in ipairs({
        "Aphrodite",
        "Apollo",
        "Ares",
        "Demeter",
        "Hephaestus",
        "Hera",
        "Hestia",
        "Poseidon",
        "Zeus",
        "Hermes",
    }) do
        addLootSetSource(lootSetData, godKey, godKey .. "Upgrade", godKey .. "TestTrait")
    end

    lootSetData.Chaos = {
        TrialUpgrade = {
            PermanentTraits = { "ChaosBuffTestTrait" },
            TemporaryTraits = { "ChaosCurseTestTrait" },
        },
    }

    env.LootSetData = lootSetData
    env.UnitSetData = {}
    addUnitSetSource(env.UnitSetData, "NPC_Arachne", "NPC_Arachne_01", "ArachneTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Narcissus", "NPC_Narcissus_01", "NarcissusTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Echo", "NPC_Echo_01", "EchoTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Hades", "NPC_Hades_Field_01", "HadesTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Medea", "NPC_Medea_01", "MedeaTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Circe", "NPC_Circe_01", "CirceTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Icarus", "NPC_Icarus_01", "IcarusTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Dionysus", "NPC_Dionysus_01", "DionysusTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Artemis", "NPC_Artemis_Field_01", "ArtemisTestTrait")
    addUnitSetSource(env.UnitSetData, "NPC_Athena", "NPC_Athena_01", "AthenaTestTrait")

    env.SpellData = {
        SeleneSpell = {
            TraitName = "SeleneSpellTrait",
        },
    }
    env.MetaUpgradeData = {
        BNBTestCard = {},
    }
    env.MetaUpgradeCardData = {
        CRDTestCard = {},
    }
    env.MetaUpgradeDefaultCardLayout = {
        { "CRDTestCard" },
    }
end

local function configureBoonBansEnv(env)
    env.rom.game.GetDisplayName = function(args)
        return args and args.Text or ""
    end
    env.CurrentRun = nil
    env.GameState = {
        MetaUpgradeState = {},
    }
    env.TraitData = {}
    configureBoonBansGameData(env)
    env.GetEquippedWeapon = function()
        return "StaffWeapon"
    end
    env.IsGameStateEligible = function()
        return true
    end
end

return {
    expectedPackId = "run-director",
    expectedModuleId = "BoonBans",
    configureEnv = configureBoonBansEnv,
}
