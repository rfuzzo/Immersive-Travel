local config = require("ImmersiveVehicles.config")

local this = {}

local logger = require("logging.logger")
this.log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = false,
    includeTimestamp = false
}

return this
