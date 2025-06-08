--- Setup MCM.
local function registerModConfig()
    local config = require("ImmersiveTravelEditor.config")
    if not config then
        local log = mwse.Logger.new()
        log:error("[ImmersiveTravelEditor] Failed to load config.")
        return
    end

    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("ImmersiveTravelEditor", config)

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

    generalCategory:createSlider({
        label = "Editor resolution",
        description = "Editor resolution, the higher the faster but less correct",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable { id = "grain", table = config }
    })

    generalCategory:createSlider({
        label = "Editor resolution max",
        description = "Editor resolution, the higher longer the load time",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable { id = "tracemax", table = config }
    })

    generalCategory:createKeyBinder({
        label = "Open Editor Keybind",
        description = "Assign a new keybind.",
        variable = mwse.mcm.createTableVariable {
            id = "openkeybind",
            table = config
        },
        allowCombinations = true
    })

    generalCategory:createKeyBinder({
        label = "Editor Place Marker Keybind",
        description = "Assign a new keybind.",
        variable = mwse.mcm.createTableVariable {
            id = "placekeybind",
            table = config
        },
        allowCombinations = true
    })
    generalCategory:createKeyBinder({
        label = "Editor Edit Marker Keybind",
        description = "Assign a new keybind.",
        variable = mwse.mcm.createTableVariable {
            id = "editkeybind",
            table = config
        },
        allowCombinations = true
    })
    generalCategory:createKeyBinder({
        label = "Editor Delete Marker Keybind",
        description = "Assign a new keybind.",
        variable = mwse.mcm.createTableVariable {
            id = "deletekeybind",
            table = config
        },
        allowCombinations = true
    })

    generalCategory:createOnOffButton({
        label = "Trace on Save",
        description = "Trace on Save.",
        variable = mwse.mcm.createTableVariable {
            id = "traceOnSave",
            table = config
        }
    })

    generalCategory:createKeyBinder({
        label = "Trace Markers Keybind",
        description = "Assign a new keybind.",
        variable = mwse.mcm.createTableVariable {
            id = "tracekeybind",
            table = config
        },
        allowCombinations = true
    })

    generalCategory:createKeyBinder({
        label = "Pin Markers Keybind",
        description = "Assign a new keybind.",
        variable = mwse.mcm.createTableVariable {
            id = "pinkeybind",
            table = config
        },
        allowCombinations = true
    })

    template:register()
end

event.register("modConfigReady", registerModConfig)
