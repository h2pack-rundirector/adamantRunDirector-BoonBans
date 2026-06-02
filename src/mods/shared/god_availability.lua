local GOD_AVAILABILITY_SHARED_ID = "run-director.god-availability"
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

function module.attach(host)
    host.shared.data.reader(GOD_AVAILABILITY_REF, {
        id = GOD_AVAILABILITY_SHARED_ID,
        fallback = {
            active = false,
            available = {},
        },
    })
end

function module.read(source)
    return source.shared.read(GOD_AVAILABILITY_REF)
end

function module.isSnapshotActive(snapshot)
    return snapshot and snapshot.active == true
end

function module.isSnapshotAvailable(snapshot, godKey)
    if not GOD_KEY_SET[godKey] then
        return true
    end
    if not module.isSnapshotActive(snapshot) then
        return true
    end
    return not snapshot.available or snapshot.available[godKey] ~= false
end

function module.isActive(source)
    return module.isSnapshotActive(module.read(source))
end

function module.isAvailable(source, godKey)
    return module.isSnapshotAvailable(module.read(source), godKey)
end

return module
