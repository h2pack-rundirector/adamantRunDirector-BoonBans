-- luacheck: globals TestRunStateLogic CurrentRun IsGodTrait

local lu = require("luaunit")

TestRunStateLogic = {}

local function MakeRuntime(values)
    values = values or {}
    return {
        data = {
            get = function(key)
                return {
                    read = function()
                        return values[key]
                    end,
                }
            end,
        },
        cache = {
            currentRun = {
                get = function(key)
                    if not CurrentRun then
                        return nil
                    end
                    CurrentRun.__testCache = CurrentRun.__testCache or {}
                    if CurrentRun.__testCache[key] == nil then
                        CurrentRun.__testCache[key] = {
                            BanPoolPickCounts = {},
                        }
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
    local runState = self.module.create()

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
    local runState = self.module.create()
    local runtime = MakeRuntime({ ImproveFirstNBoonRarity = 2 })

    lu.assertTrue(runState.hasCurrentRun(runtime))
    lu.assertEquals(runState.getBanPoolIndex(runtime, "Apollo"), 1)
    lu.assertEquals(runState.recordAcquisition(runtime, "Apollo"), 1)
    lu.assertEquals(runState.getBanPoolIndex(runtime, "Apollo"), 2)

    local oldRun = CurrentRun
    CurrentRun = {}
    lu.assertEquals(runState.getBanPoolIndex(runtime, "Apollo"), 1)
    CurrentRun = oldRun
    lu.assertEquals(runState.getBanPoolIndex(runtime, "Apollo"), 2)
end

function TestRunStateLogic:testForcedRarityConsumesOnlyWhenConfiguredAndGodTrait()
    local runState = self.module.create()
    local runtime = MakeRuntime({ ImproveFirstNBoonRarity = 1 })

    lu.assertEquals(runState.getForcedRarityRemaining(runtime), 1)
    lu.assertTrue(runState.shouldForceRarity(runtime, { GodLoot = true }))
    lu.assertTrue(runState.consumeForcedRarity(runtime, "ApolloStrike"))
    lu.assertEquals(runState.getForcedRarityRemaining(runtime), 0)
    lu.assertFalse(runState.consumeForcedRarity(runtime, "ApolloStrike"))
end

function TestRunStateLogic:testMissingCurrentRunReturnsSafeDefaults()
    CurrentRun = nil
    local runState = self.module.create()
    local runtime = MakeRuntime({ ImproveFirstNBoonRarity = 3 })

    lu.assertFalse(runState.hasCurrentRun(runtime))
    lu.assertEquals(runState.getBanPoolIndex(runtime, "Apollo"), 1)
    lu.assertNil(runState.recordAcquisition(runtime, "Apollo"))
    lu.assertEquals(runState.getForcedRarityRemaining(runtime), 0)
    lu.assertFalse(runState.consumeForcedRarity(runtime, "ApolloStrike"))
end

function TestRunStateLogic:testForcedRarityDoesNotConsumeForNonGodTrait()
    IsGodTrait = function()
        return false
    end
    local runState = self.module.create()
    local runtime = MakeRuntime({ ImproveFirstNBoonRarity = 1 })

    lu.assertFalse(runState.consumeForcedRarity(runtime, "NonGodTrait"))
    lu.assertEquals(runState.getForcedRarityRemaining(runtime), 1)
end
