local data = import("mods/controls/TraitSource/data.lua")
local runtime = import("mods/controls/TraitSource/runtime.lua")
local ui = import("mods/controls/TraitSource/ui.lua", nil, {
    data = data,
    runtime = runtime,
})

return {
    prepare = data.prepare,
    storage = data.storage,
    createRuntime = runtime.create,
    createUi = ui.create,
    commands = ui.commands,
    views = ui.views,
}
