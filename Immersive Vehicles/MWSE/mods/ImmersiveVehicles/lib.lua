local lib = require("ImmersiveTravel.lib")
local interop = require("ImmersiveTravel.interop")

local this = {}


local logger = require("logging.logger")
this.log = logger.new {
    name = "Immersive Vehicles",
    logLevel = "INFO", -- TODO add to mcm?
    logToConsole = false,
    includeTimestamp = false
}

--- check if valid mount
---@param id string
---@return boolean
function this.validMount(id)
    return lib.is_in(interop.vehicles, id)
end

return this
