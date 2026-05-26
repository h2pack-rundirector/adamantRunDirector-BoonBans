local GOD_AVAILABILITY_CACHE = "run-director.god-availability"
local GOD_AVAILABILITY_REF = "GodAvailability"
local GOD_KEYS = {
    "Aphrodite",
    "Apollo",
    "Ares",
    "Demeter",
    "Hephaestus",
    "Hera",
    "Hestia",
    "Poseidon",
    "Zeus",
}
local GOD_KEY_SET = {}

for _, godKey in ipairs(GOD_KEYS) do
    GOD_KEY_SET[godKey] = true
end

local module = {}

function module.buildCacheDeclarations()
    return {
        [GOD_AVAILABILITY_REF] = {
            domain = "shared",
            id = GOD_AVAILABILITY_CACHE,
            access = "reader",
            fallback = {
                active = false,
                available = {},
            },
        },
    }
end

function module.create()
    local api = {}
    api.buildCacheDeclarations = module.buildCacheDeclarations

    function api.read(source)
        return source.cache.shared.read(GOD_AVAILABILITY_REF)
    end

    function api.isSnapshotActive(snapshot)
        return snapshot and snapshot.active == true
    end

    function api.isSnapshotAvailable(snapshot, godKey)
        if not GOD_KEY_SET[godKey] then
            return true
        end
        if not api.isSnapshotActive(snapshot) then
            return true
        end
        return not snapshot.available or snapshot.available[godKey] ~= false
    end

    function api.isActive(source)
        return api.isSnapshotActive(api.read(source))
    end

    function api.isAvailable(source, godKey)
        return api.isSnapshotAvailable(api.read(source), godKey)
    end

    return api
end

return module
