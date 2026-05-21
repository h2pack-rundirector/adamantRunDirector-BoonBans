-- luacheck: globals TestRunStateLogic CurrentRun IsGodTrait

local lu = require("luaunit")

TestRunStateLogic = {}

local function MakeStore(values)
    values = values or {}
    return {
        read = function(key)
            return values[key]
        end,
    }
end

local function MakeHost()
    return {
        cache = {
            currentRun = {
                get = function(key, factory)
                    if not CurrentRun then
                        return nil
                    end
                    CurrentRun.__testCache = CurrentRun.__testCache or {}
                    if CurrentRun.__testCache[key] == nil then
                        CurrentRun.__testCache[key] = factory()
                    end
                    return CurrentRun.__testCache[key]
                end,
            },
        },
    }
end

function TestRunStateLogic:setUp()
    CurrentRun = {}
    IsGodTrait = function()
        return true
    end
    self.module = dofile("src/mods/logic/run_state.lua")
end

function TestRunStateLogic:testScratchSupportsValuesMapsAndTake()
    local runState = self.module.create(MakeHost(), MakeStore())

    runState.scratch.set("activeGod", "Apollo")
    lu.assertEquals(runState.scratch.get("activeGod"), "Apollo")

    runState.scratch.mapSet("offers", "DuoBoon", "ZeusUpgrade")
    lu.assertEquals(runState.scratch.mapGet("offers", "DuoBoon"), "ZeusUpgrade")
    lu.assertEquals(runState.scratch.mapTake("offers", "DuoBoon"), "ZeusUpgrade")
    lu.assertNil(runState.scratch.mapGet("offers", "DuoBoon"))

    runState.scratch.clear("activeGod")
    lu.assertNil(runState.scratch.get("activeGod"))
end

function TestRunStateLogic:testRunCacheTracksAcquisitionsPerCurrentRun()
    local runState = self.module.create(MakeHost(), MakeStore({ ImproveFirstNBoonRarity = 2 }))

    lu.assertTrue(runState.hasCurrentRun())
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 1)
    lu.assertEquals(runState.recordAcquisition("Apollo"), 1)
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 2)

    local oldRun = CurrentRun
    CurrentRun = {}
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 1)
    CurrentRun = oldRun
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 2)
end

function TestRunStateLogic:testForcedRarityConsumesOnlyWhenConfiguredAndGodTrait()
    local runState = self.module.create(MakeHost(), MakeStore({ ImproveFirstNBoonRarity = 1 }))

    lu.assertEquals(runState.getForcedRarityRemaining(), 1)
    lu.assertTrue(runState.shouldForceRarity({ GodLoot = true }))
    lu.assertTrue(runState.consumeForcedRarity("ApolloStrike"))
    lu.assertEquals(runState.getForcedRarityRemaining(), 0)
    lu.assertFalse(runState.consumeForcedRarity("ApolloStrike"))
end

function TestRunStateLogic:testMissingCurrentRunReturnsSafeDefaults()
    CurrentRun = nil
    local runState = self.module.create(MakeHost(), MakeStore({ ImproveFirstNBoonRarity = 3 }))

    lu.assertFalse(runState.hasCurrentRun())
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 1)
    lu.assertNil(runState.recordAcquisition("Apollo"))
    lu.assertEquals(runState.getForcedRarityRemaining(), 0)
    lu.assertFalse(runState.consumeForcedRarity("ApolloStrike"))
end

function TestRunStateLogic:testForcedRarityDoesNotConsumeForNonGodTrait()
    IsGodTrait = function()
        return false
    end
    local runState = self.module.create(MakeHost(), MakeStore({ ImproveFirstNBoonRarity = 1 }))

    lu.assertFalse(runState.consumeForcedRarity("NonGodTrait"))
    lu.assertEquals(runState.getForcedRarityRemaining(), 1)
end
