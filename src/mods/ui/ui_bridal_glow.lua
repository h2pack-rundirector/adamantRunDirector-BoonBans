local deps = ...
local mutedTextOpts = {
    color = deps.style.MUTED_TEXT_COLOR,
}
local bridalGlowTargetsByRoot = {}
local activeBridalGlowRootId = ""

local EMPTY_LIST = {}

local function WriteSelectedBoon(ui, boonKey)
    ui.data.get("BridalGlowTargetBoon"):write(boonKey or "")
end

local function GetBridalGlowEligibleTargets(root, ui)
    if not root then
        return EMPTY_LIST
    end

    local cached = bridalGlowTargetsByRoot[root.id]
    if cached then
        return cached
    end

    local targets = {}
    ui.controls.get(root.controlName):collectBridalGlowTargets(targets)
    bridalGlowTargetsByRoot[root.id] = targets
    return targets
end

local function FindBridalGlowTarget(root, targetKey, ui)
    if not root then
        return nil
    end
    return ui.controls.get(root.controlName):findBridalGlowTarget(targetKey)
end

local function FindBridalGlowRootForTarget(roots, selectedBoonKey, ui)
    if not selectedBoonKey or selectedBoonKey == "" then
        return nil
    end

    for _, root in ipairs(roots) do
        if FindBridalGlowTarget(root, selectedBoonKey, ui) ~= nil then
            return root
        end
    end
    return nil
end

local function EnsureBridalGlowRootSelection(roots, selectedBoonKey, ui)
    if activeBridalGlowRootId ~= "" then
        for _, root in ipairs(roots) do
            if root.id == activeBridalGlowRootId then
                return root
            end
        end
    end

    local matchedRoot = FindBridalGlowRootForTarget(roots, selectedBoonKey, ui)
    if matchedRoot then
        activeBridalGlowRootId = matchedRoot.id
        return matchedRoot
    end

    local fallback = roots[1]
    activeBridalGlowRootId = fallback and fallback.id or ""
    return fallback
end

local function GetCurrentBridalGlowTargetText(eligibleRoots, selectedBoonKey, ui)
    if selectedBoonKey == nil or selectedBoonKey == "" then
        return "Current Target: Random"
    end

    for _, root in ipairs(eligibleRoots) do
        local target = FindBridalGlowTarget(root, selectedBoonKey, ui)
        if target ~= nil then
            return "Current Target: " .. target.label
        end
    end

    return "Current Target: Random"
end

local module = {}

function module.draw(ui, eligibleRoots)
    local draw = ui.draw
    local state = ui.data
    local imgui = draw.imgui
    local targetField = state.get("BridalGlowTargetBoon")
    local selectedBoonKey = targetField:read() or ""

    draw.widgets.text("Choose the Olympian god and boon pool Bridal Glow can target.")
    draw.widgets.text(GetCurrentBridalGlowTargetText(eligibleRoots, selectedBoonKey, ui))
    draw.widgets.separator()

    if #eligibleRoots == 0 then
        draw.widgets.text("No eligible Olympian gods are currently available.", mutedTextOpts)
        return
    end

    local selectedRoot = EnsureBridalGlowRootSelection(eligibleRoots, selectedBoonKey, ui)
    local selectedRootId = selectedRoot and selectedRoot.id or nil
    local eligibleTargets = GetBridalGlowEligibleTargets(selectedRoot, ui)

    imgui.BeginChild("BoonBansBridalGlowGods", 220, 220, true)
    draw.widgets.text("Eligible Gods", mutedTextOpts)
    draw.widgets.separator()
    for _, root in ipairs(eligibleRoots) do
        if imgui.Selectable(root.label, root.id == selectedRootId) then
            activeBridalGlowRootId = root.id
            selectedRoot = root
            selectedRootId = root.id
            eligibleTargets = GetBridalGlowEligibleTargets(selectedRoot, ui)
        end
    end
    imgui.EndChild()

    imgui.SameLine()

    imgui.BeginChild("BoonBansBridalGlowBoons", 0, 220, true)
    draw.widgets.text("Eligible Boons", mutedTextOpts)
    draw.widgets.separator()
    if imgui.Selectable("Random", selectedBoonKey == "") then
        WriteSelectedBoon(ui, "")
        selectedBoonKey = ""
    end
    for _, target in ipairs(eligibleTargets) do
        if imgui.Selectable(target.label, target.key == selectedBoonKey) then
            WriteSelectedBoon(ui, target.key)
            selectedBoonKey = target.key
        end
    end
    imgui.EndChild()
end

return module
