local elib   = require("ImmersiveTravelEditor.lib")
local ui     = require("ImmersiveTravelEditor.ui")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("ImmersiveTravelEditor.config")
if not config then return end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- @param e keyDownEventData
local function editor_keyDownCallback(e)
    -- editor menu
    if e.keyCode == config.openkeybind.keyCode then
        ui.createEditWindow()
    end
end
event.register(tes3.event.keyDown, editor_keyDownCallback)

--- Cleanup on save load
--- @param e loadEventData
local function editloadCallback(e)
    elib.editorMarkerMesh = tes3.loadMesh(elib.editorMarkerId)
    elib.portMarkerMesh = tes3.loadMesh(elib.portMarkerId)
    elib.nodeMarkerMesh = tes3.loadMesh(elib.nodeMarkerId)
    elib.sphereMarkerMesh = tes3.loadMesh(elib.sphereMarkerId)

    -- arrows
    -- elib.arrow = tes3.loadMesh("mwse\\widget_arrow_y.nif"):clone()
    -- elib.arrow.scale = 70
    --  widgets.nif
    elib.arrow = tes3.loadMesh("mwse\\widgets.nif"):getObjectByName("unitArrows")
    elib.arrow.scale = 70

    elib.arrowz = tes3.loadMesh("mwse\\widget_arrow_z.nif"):clone()

    local debugnode = niNode.new()
    tes3.game.worldRoot:attachChild(debugnode)
    elib.debugRoot = debugnode

    local editornode = niNode.new()
    tes3.game.worldRoot:attachChild(editornode)
    -- elib.editorRoot = editornode
    elib.editorRoot = tes3.worldController.vfxManager.worldVFXRoot

    elib.cleanup()
end
event.register(tes3.event.load, editloadCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravelEditor.mcm")
