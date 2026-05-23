local GOD_AVAILABILITY_CACHE = "run-director.god-availability"
local DEFAULT_AVAILABILITY = {
    active = false,
    available = {},
}

local module = {}

local function readSnapshot(source)
    return source.cache.shared.read(GOD_AVAILABILITY_CACHE, DEFAULT_AVAILABILITY)
end

function module.create()
    local api = {}

    function api.isActive(source)
        return readSnapshot(source).active == true
    end

    function api.isAvailable(source, godKey)
        local snapshot = readSnapshot(source)
        if snapshot.active ~= true then
            return true
        end
        local availableByGod = type(snapshot.available) == "table" and snapshot.available or nil
        if availableByGod and availableByGod[godKey] ~= nil then
            return availableByGod[godKey] ~= false
        end
        return true
    end

    return api
end

return module
