---@class ITWAConfig
---@field mod string
---@field id string
---@field version number
---@field author string
---@field logLevel string
---@field modEnabled boolean
---@field spawnChance number
---@field spawnExlusionRadius number
---@field spawnRadius number
---@field cullRadius number
---@field budget number
local defaultConfig = {
    mod = "Immersive Travel World Addon",
    id = "ITWA",
    version = 1.0,
    author = "rfuzzo",
    -- configs
    logLevel = "INFO",
    modEnabled = true,
    -- configs
    spawnChance = 10,
    spawnExlusionRadius = 2,
    spawnRadius = 3,
    cullRadius = 4,
    budget = 100
}

return mwse.loadConfig("ImmersiveTravelAddonWorld", defaultConfig)
