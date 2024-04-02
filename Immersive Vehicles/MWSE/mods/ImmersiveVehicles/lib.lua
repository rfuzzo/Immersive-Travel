local this = {}

local logger = require("logging.logger")
this.log = logger.new {
    name = "Immersive Vehicles",
    logLevel = "DEBUG", -- TODO add to mcm?
    logToConsole = false,
    includeTimestamp = false
}

return this
