local lib            = require("ImmersiveTravel.lib")
local interop        = require("ImmersiveTravel.interop")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")
local PositionRecord = require("ImmersiveTravel.models.PositionRecord")
local RouteId        = require("ImmersiveTravel.models.RouteId")
local elib           = require("ImmersiveTravelEditor.lib")

local config         = require("ImmersiveTravelEditor.config")
if not config then return end

local this             = {}

local portMenuSearchId = tes3ui.registerID("it:MenuPort_Search")

-- preview
local preview          = nil ---@type SPreviewData | nil

-- editor
local editmode         = false
local filter_text      = ""

-- usings
local EEditorMode      = elib.EEditorMode
local EMarkerType      = elib.EMarkerType
local log              = elib.log

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

function this.unregisterEvents()

end

function this.portsPanel(menu, reload)
    -- load services
    local services = GRoutesManager.GetServices()
    if not services then return end

    -- get current service
    if not elib.currentServiceName then
        elib.currentServiceName = table.keys(services)[1]
    end
    if elib.editorData then elib.currentServiceName = elib.editorData.service.class end
    local service = services[elib.currentServiceName]
    if not service then return end

    local input = menu:createTextInput { text = filter_text, id = portMenuSearchId }
    input.widget.lengthLimit = 31
    input.widget.eraseOnFirstKey = true
    input:register(tes3.uiEvent.keyEnter, function()
        local text = menu:findChild(portMenuSearchId).text
        filter_text = text
        elib.cleanup()
        menu:destroy()

        reload()
    end)

    -- Create layout
    local label = menu:createLabel { text = "Loaded routes (" .. elib.currentServiceName .. ")" }
    label.borderBottom = 5

    -- get destinations
    local pane = menu:createVerticalScrollPane { id = "sortedPane" }

    -- list all ports
    for _, portName in ipairs(service:GetPorts()) do
        -- filter
        local filter = filter_text:lower()
        if filter_text ~= "" then
            if (not string.find(portName:lower(), filter)) then
                goto continue
            end
        end

        local portCount = table.size(service.ports[portName].data)

        local button = pane:createButton {
            id = "button_port" .. portName,
            text = portName .. " (" .. portCount .. ")"
        }
        button:register(tes3.uiEvent.mouseClick, function()
            -- teleport to port
            local portData = service:GetPort(portName, service.mount)
            if portData then
                tes3.positionCell({
                    reference = tes3.mobilePlayer,
                    position  = portData:EndPos()
                })
            else
                elib.teleportToCell(portName)
            end
        end)

        ::continue::
    end

    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)


    -- buttons
    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment

    tes3ui.acquireTextInput(input)
end

return this
