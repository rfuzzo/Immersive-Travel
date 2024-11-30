local elib   = require("ImmersiveTravelEditor.lib")
local ui     = require("ImmersiveTravelEditor.ui")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("ImmersiveTravelEditor.config")
if not config then return end

--[[
Current Usage (Debug)
- Open route editor 						... R-Ctrl
- move a marker 							... L-Ctrl
- delete a marker 							... Del
- exit edit mode 							... L-Ctrl
- add a marker								... >
- start traveling            		        ... <

--]]


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
    -- arrowMarkerMesh = tes3.loadMesh(arrowMarkerId)

    -- widgets.nif
    elib.arrow = tes3.loadMesh("mwse\\widget_arrow_y.nif"):clone()
    elib.arrow.scale = 70

    elib.arrowz = tes3.loadMesh("mwse\\widget_arrow_z.nif"):clone()

    elib.cleanup()
end
event.register(tes3.event.load, editloadCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravelEditor.mcm")
