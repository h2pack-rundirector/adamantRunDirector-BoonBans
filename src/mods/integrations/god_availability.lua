local GOD_AVAILABILITY_INTEGRATION = "run-director.god-availability"
local AVAILABILITY_CHANGED_EVENT = "availabilityChanged"
local PROVIDER_CHANGED_EVENT = "providerChanged"

local module = {}

local function poll(source, methodName, fallback, ...)
    if not source then
        return fallback
    end
    if source.pollIntegration then
        return source.pollIntegration(GOD_AVAILABILITY_INTEGRATION, methodName, fallback, ...)
    end
    if source.integrations and source.integrations.poll then
        return source.integrations.poll(GOD_AVAILABILITY_INTEGRATION, methodName, fallback, ...)
    end
    return fallback
end

function module.create()
    local seeded = false
    local active = false
    local availableByGod = nil

    local function applySnapshot(snapshot)
        seeded = true
        active = type(snapshot) == "table" and snapshot.active == true
        availableByGod = type(snapshot) == "table" and type(snapshot.available) == "table" and snapshot.available or nil
    end

    local api = {}

    function api.refresh(source)
        local snapshot = poll(source, "snapshot", nil)
        if type(snapshot) == "table" then
            applySnapshot(snapshot)
            return true
        end

        seeded = true
        active = poll(source, "isActive", false) == true
        availableByGod = nil
        return active
    end

    function api.listen(host)
        host.integrations.listen(GOD_AVAILABILITY_INTEGRATION, AVAILABILITY_CHANGED_EVENT, function(payload)
            applySnapshot(payload)
        end)
        host.integrations.listen(GOD_AVAILABILITY_INTEGRATION, PROVIDER_CHANGED_EVENT, function(payload)
            if type(payload) == "table" and payload.enabled == false then
                applySnapshot({ active = false, available = {} })
            else
                seeded = false
            end
        end)
    end

    function api.isActive(source)
        if not seeded then
            api.refresh(source)
        end
        return active == true
    end

    function api.isAvailable(source, godKey)
        if not api.isActive(source) then
            return true
        end
        if availableByGod and availableByGod[godKey] ~= nil then
            return availableByGod[godKey] ~= false
        end
        return poll(source, "isAvailable", true, godKey) ~= false
    end

    return api
end

return module
