local logic = {}

function logic.bind(data)
    local runStateModule = import("mods/logic/run_state.lua")
    local banResolverModule = import("mods/logic/ban_resolver.lua")
    local acquisition = import("mods/logic/acquisition.lua").bind(data)
    local npcLogic = import("mods/logic/npc_logic.lua").bind(data)
    local lootLogic = import("mods/logic/loot_logic.lua").bind(data)

    function logic.buildCacheDeclarations()
        return runStateModule.buildCacheDeclarations()
    end

    local function createRuntimeStore(resolveRuntime)
        return {
            get = function(alias)
                return resolveRuntime().data.get(alias)
            end,
            read = function(alias, ...)
                return resolveRuntime().data.read(alias, ...)
            end,
            cache = {
                currentRun = {
                    get = function(name)
                        return resolveRuntime().cache.currentRun.get(name)
                    end,
                },
            },
        }
    end

    local function createHookHost(module, resolveRuntime, setRuntime)
        local activeHost = nil
        local runtimeStore = createRuntimeStore(resolveRuntime)
        local hookHost = {
            hooks = {},
            isEnabled = function()
                return activeHost and activeHost.isEnabled() or module.isEnabled()
            end,
            log = function(fmt, ...)
                return (activeHost or module).log(fmt, ...)
            end,
            logIf = function(fmt, ...)
                return (activeHost or module).logIf(fmt, ...)
            end,
        }

        function hookHost.hooks.wrap(path, keyOrHandler, maybeHandler)
            local key = nil
            local handler = keyOrHandler
            if maybeHandler ~= nil then
                key = keyOrHandler
                handler = maybeHandler
            end
            local function adapted(host, runtime, base, ...)
                local previousHost = activeHost
                local previousRuntime = resolveRuntime()
                activeHost = host
                setRuntime(runtime)
                local results = { pcall(handler, base, ...) }
                activeHost = previousHost
                setRuntime(previousRuntime)
                if not results[1] then
                    error(results[2], 0)
                end
                return table.unpack(results, 2)
            end
            if key ~= nil then
                return module.hooks.wrap(path, key, adapted)
            end
            return module.hooks.wrap(path, adapted)
        end

        return hookHost, runtimeStore
    end

    function logic.registerHooks(module)
        local currentRuntime = nil
        local function resolveRuntime()
            return currentRuntime
        end
        local function setRuntime(runtime)
            currentRuntime = runtime
        end
        local hookHost, store = createHookHost(module, resolveRuntime, setRuntime)
        local runState = runStateModule.create(function()
            return currentRuntime
        end)
        local banResolver = banResolverModule.create(
            data.catalog,
            data.banPools,
            data.banConfig,
            store,
            runState,
            data.godDefs
        )

        module.logIf("[Micro] GodCatalog populated.")
        acquisition.registerHooks(hookHost, runState, banResolver)
        npcLogic.registerHooks(hookHost, store, banResolver)
        lootLogic.registerHooks(hookHost, store, runState, banResolver)
    end

    return logic
end

return logic
