--- Setup MCM.
local function registerModConfig()
    local config = require("ImmersiveTravelAddonWorld.config")
    if not config then
        local log = mwse.Logger.new()
        log:error("[ImmersiveTravelAddonWorld] Failed to load config.")
        return
    end

    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("ImmersiveTravelAddonWorld", config)

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

    generalCategory:createOnOffButton({
        label = "Enable Mod",
        description = "Enable Mod.",
        variable = mwse.mcm.createTableVariable {
            id = "modEnabled",
            table = config
        }
    })

    -- //////////////////////

    generalCategory:createSlider({
        label = "Spawn Chance",
        description = "Chance a mount is spawned in the world",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "spawnChance",
            table = config
        }
    })

    generalCategory:createSlider({
        label = "Spawn Exlusion Radius",
        description = "The radius in cells a mount cannot be spawned around another mount",
        min = 1,
        max = 40,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "spawnExlusionRadius",
            table = config
        }
    })

    generalCategory:createSlider({
        label = "Spawn Radius",
        description = "Radius within which mounts are spawned around player",
        min = 1,
        max = 40,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "spawnRadius",
            table = config
        }
    })

    generalCategory:createSlider({
        label = "Reference Budget",
        description = "The amount of mounts allowed at one time",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable { id = "budget", table = config }
    })

    generalCategory:createSlider({
        label = "Cull Radius",
        description = "The distance in cells after which mounts get destroyed",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "cullRadius",
            table = config
        }
    })

    -- generalCategory:createOnOffButton({
    --     label = "Enable Evasion",
    --     description = "Enable evasion mechanics.",
    --     variable = mwse.mcm.createTableVariable {
    --         id = "enableEvade",
    --         table = config
    --     }
    -- })

    template:register()
end

event.register("modConfigReady", registerModConfig)
