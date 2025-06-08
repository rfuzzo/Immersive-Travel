--- Setup MCM.
local function registerModConfig()
    local config = require("ImmersiveVehicles.config")
    if not config then
        local log = mwse.Logger.new()
        log:error("[ImmersiveVehicles] Failed to load config.")
        return
    end

    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("ImmersiveVehicles", config)

    local page = template:createSideBarPage({ label = "Settings" })
    page.sidebar:createInfo {
        text = ("%s v%.1f\n\nBy %s"):format(config.mod, config.version,
            config.author)
    }

    local settingsPage = page:createCategory("Settings")
    local generalCategory = settingsPage:createCategory("General")

    generalCategory:createLogLevelOptions {
        config = config,
        configKey = "logLevel",
    }

    template:register()
end

event.register("modConfigReady", registerModConfig)
