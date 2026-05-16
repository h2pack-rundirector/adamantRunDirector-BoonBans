local lu = require("luaunit")
local harness = dofile("../../Setup/tests/module_entrypoint_harness.lua")

TestEntrypoint = {}

local function configureBoonBansEnv(env)
    env.rom.game.Color = harness.makeColorTable()
    env.rom.game.GetDisplayName = function(args)
        return args and args.Text or ""
    end
    env.CurrentRun = nil
    env.GameState = {
        MetaUpgradeState = {},
    }
    env.TraitData = {}
    env.LootSetData = {
        Loot = {
            WeaponUpgrade = {
                Traits = {},
            },
        },
    }
    env.UnitSetData = {}
    env.SpellData = {}
    env.MetaUpgradeData = {}
    env.MetaUpgradeCardData = {}
    env.MetaUpgradeDefaultCardLayout = {}
    env.GetEquippedWeapon = function()
        return "StaffWeapon"
    end
    env.IsGameStateEligible = function()
        return true
    end
end

function TestEntrypoint:testMainLuaBootsRealModule()
    local boot = harness.bootModule({
        pluginGuid = "adamant-RunDirector_BoonBans",
        moduleSrcDir = "src",
        configureEnv = configureBoonBansEnv,
    })

    lu.assertNotNil(boot.host)
    lu.assertEquals(boot.host.getIdentity().id, "BoonBans")
    lu.assertEquals(boot.host.getIdentity().modpack, "run-director")
    lu.assertEquals(#boot.callbacks.imgui, 1)
    lu.assertEquals(#boot.callbacks.menuBar, 2)
end
