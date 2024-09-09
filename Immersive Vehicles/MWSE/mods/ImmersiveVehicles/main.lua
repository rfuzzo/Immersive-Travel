local GTrackingManager = require("ImmersiveTravel.GTrackingManager")
local interop          = require("ImmersiveTravel.interop")

local lib              = require("ImmersiveVehicles.lib")
local ui               = require("ImmersiveVehicles.ui")
local config           = require("ImmersiveVehicles.config")

local log              = lib.log

--#region debugging

-- CONSTANTS

local localmodpath     = "mods\\ImmersiveVehicles\\"

-- debug
local mountMarkerMesh  = nil
local mountMarker      = nil ---@type niNode?
local editmode         = false
local mountData        = nil ---@type CVehicle?
local dbg_mount_id     = nil ---@type string?

--- @param e keyDownEventData
local function keyDownCallback(e)
    if not e.isAltDown then
        return
    end

    -- leave editor and spawn vehicle
    if config.logLevel == "DEBUG" then
        if e.keyCode == tes3.scanCode["o"] and editmode and mountMarker and dbg_mount_id then
            -- spawn vehicle
            local obj = tes3.createReference {
                object = dbg_mount_id,
                position = mountMarker.translation,
                orientation = mountMarker.rotation:toEulerXYZ(),
                scale = mountMarker.scale
            }
            obj.facing = tes3.player.facing

            -- remove marker
            local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            vfxRoot:detachChild(mountMarker)
            mountMarker = nil
            editmode = false
        elseif e.keyCode == tes3.scanCode["o"] and not editmode then
            local buttons = {}
            for id, className in pairs(interop.vehicles) do
                table.insert(buttons, {
                    text = id,
                    callback = function(e)
                        mountData = interop.getVehicleStaticData(id)
                        if not mountData then return nil end
                        -- visualize placement node
                        local target = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * (256 / mountData.scale)

                        mountMarkerMesh = tes3.loadMesh(mountData.mesh)
                        local child = mountMarkerMesh:clone()
                        child.translation = target
                        child.scale = mountData.scale
                        child.appCulled = false
                        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                        ---@diagnostic disable-next-line: param-type-mismatch
                        vfxRoot:attachChild(child)
                        vfxRoot:update()
                        mountMarker = child

                        -- enter placement mode
                        editmode = true
                        dbg_mount_id = id
                    end,
                })
            end
            tes3ui.showMessageMenu({ id = "rf_dbg_iv", message = "Choose your mount", buttons = buttons, cancels = true })
        end
    end
end
event.register(tes3.event.keyDown, keyDownCallback)


--- visualize on tick
--- @param e simulatedEventData
local function simulatedCallback(e)
    -- visualize mount scene node
    if config.logLevel == "DEBUG" then
        if editmode and mountMarker and mountData then
            local from = tes3.getPlayerEyePosition() + (tes3.getPlayerEyeVector() * 500.0 * mountData.scale)
            if mountData.freedomtype == "boat" then
                from.z = mountData.offset * mountData.scale
            elseif mountData.freedomtype == "ground" then
                local z = lib.getGroundZ(from + tes3vector3.new(0, 0, 200))
                if not z then
                    from.z = 0
                else
                    from.z = z
                end
            end

            mountMarker.translation = from
            local m = tes3matrix33.new()
            m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y, tes3.player.orientation.z)
            mountMarker.rotation = m
            mountMarker:update()
        end
    end
end
event.register(tes3.event.simulated, simulatedCallback)



-- --- Cleanup on save load
-- --- @param e loadEventData
-- local function loadCallback(e)
--     travelMarkerMesh = tes3.loadMesh(travelMarkerId)
-- end
-- event.register(tes3.event.load, loadCallback)

--#endregion


--- @param e activateEventData
local function activateCallback(e)
    GTrackingManager.getInstance():OnActivate(e.target)
end
event.register(tes3.event.activate, activateCallback)

-- upon entering the dialog menu, create the travel menu
---@param e uiActivatedEventData
local function onMenuDialog(e)
    local menuDialog = e.element
    local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor") ---@cast mobileActor tes3mobileActor
    if mobileActor.actorType == tes3.actorType.npc then
        local ref = mobileActor.reference
        local obj = ref.baseObject
        local npc = obj ---@cast obj tes3npc

        -- TODO add other mounts
        if npc.class.id == "Shipmaster" then
            log:debug("createPurchaseTopic for %s", npc.id)
            ui.createPurchaseTopic(menuDialog, ref)
            menuDialog:updateLayout()
        end
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveVehicles.mcm")

--#region immersive travel integration

-- boats
interop.insertVehicle("a_mushroomdola_iv", "CMushroomdola")
interop.insertVehicle("a_sailboat_iv", "CSailboat")
interop.insertVehicle("a_rowboat_iv", "CRowboat")
interop.insertVehicle("a_telvcatboat_iv", "CTelvcatboat")
interop.insertVehicle("a_canoe_01", "CCanoe")
-- TODO add other mounts
-- interop.insertVehicle("a_cliffracer", nil)
-- interop.insertVehicle("a_nix-hound", nil)

--#endregion

--#region crafting framework integration

local CraftingFramework = include("CraftingFramework")
if not CraftingFramework then return end

local enterVehicle = {
    text = "Get in/out",
    callback = function(e)
        GTrackingManager.getInstance():OnActivate(e.reference)
    end
}

local destroyVehicle = {
    text = "Destroy",
    callback = function(e)
        GTrackingManager.getInstance():OnDestroy(e.reference)
    end
}

-- MATERIALS

--Register your materials
local materials = {
    {
        id = "mushroom",
        name = "Mushroom",
        ids = {
            "ingred_russula_01",
            "ingred_coprinus_01",
            "ingred_bc_bungler's_bane",
            "ingred_bc_hypha_facia",
            "ingred_bloat_01"
        }
    },

}
CraftingFramework.Material:registerMaterials(materials)

-- RECIPES

---get recipe with data
---@param id string
local function getRecipeFor(id)
    local class = interop.getVehicleStaticData(id)
    if not class then
        return nil
    end
    local data = class.userData

    if data and data.materials and class.scale then
        local recipe = {
            id = "recipe_" .. id,
            craftableId = id,
            soundType = "wood",
            category = "Vehicles",
            materials = data.materials,
            scale = class.scale,
            craftedOnly = false,
            additionalMenuOptions = { enterVehicle, destroyVehicle },
            -- secondaryMenu         = false,
            quickActivateCallback = function(_, e)
                GTrackingManager.getInstance():OnActivate(e.reference)
            end
        }

        return recipe
    end
    return nil
end



local function registerRecipes(e)
    ---@diagnostic disable-next-line: undefined-doc-name
    ---@type CraftingFramework.Recipe.data[]
    local recipes = {}

    for id, className in pairs(interop.vehicles) do
        local r = getRecipeFor(id)
        if r then
            lib.log:debug("registering recipe for %s", id)
            table.insert(recipes, r)
        end
    end

    -- lib.log:debug("register %s Recipes", #recipes)
    -- for index, value in ipairs(recipes) do
    --     lib.log:debug("found recipe %s", value.id)
    -- end

    if e.menuActivator then e.menuActivator:registerRecipes(recipes) end
end
event.register("Ashfall:ActivateBushcrafting:Registered", registerRecipes)

--#endregion
