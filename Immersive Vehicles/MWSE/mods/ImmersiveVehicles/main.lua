local lib = require("ImmersiveVehicles.lib")
local interop = require("ImmersiveTravel.interop")
local CPlayerSteerManager = require("ImmersiveVehicles.CPlayerSteerManager")

local log = lib.log

local DEBUG = false


-- CONSTANTS

local localmodpath = "mods\\ImmersiveVehicles\\"
local fullmodpath = "Data Files\\MWSE\\" .. localmodpath

-- TODO debug
local travelMarkerId = "marker_arrow.nif"
local travelMarkerMesh = nil
local mountMarkerMesh = nil
local travelMarker = nil ---@type niNode?
local mountMarker = nil ---@type niNode?
local editmode = false

--[[

local dbg_mount_id = nil ---@type string?

--- @param e keyDownEventData
local function keyDownCallback(e)
    -- leave editor and spawn vehicle
    if DEBUG then
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
        elseif e.keyCode == tes3.scanCode["o"] and not editmode and not is_on_mount then
            local buttons = {}
            local mounts = loadMountNames()
            for _, id in ipairs(mounts) do
                table.insert(buttons, {
                    text = id,
                    callback = function(e)
                        mountData = loadMountData(getMountForId(id))
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
    if DEBUG then
        if editmode and mountMarker and mountData then
            local from = tes3.getPlayerEyePosition() + (tes3.getPlayerEyeVector() * 500.0 * mountData.scale)
            if mountData.freedomtype == "boat" then
                from.z = mountData.offset * mountData.scale
            elseif mountData.freedomtype == "ground" then
                local z = getGroundZ(from + tes3vector3.new(0, 0, 200))
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


]]

-- --- Cleanup on save load
-- --- @param e loadEventData
-- local function loadCallback(e)
--     travelMarkerMesh = tes3.loadMesh(travelMarkerId)
-- end
-- event.register(tes3.event.load, loadCallback)

--- @param e activateEventData
local function activateCallback(e)
    CPlayerSteerManager.getInstance():OnActivate(e.target)
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

        -- check if npc is Shipmaster
        if npc.class.id == "Shipmaster" then
            log:debug("createPurchaseTopic for %s", npc.id)
            CPlayerSteerManager.createPurchaseTopic(menuDialog, ref)
            menuDialog:updateLayout()
        end
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })



-- //////////////////////////////////////////////////////////////////////////////////////////
-- CRAFTING FRAMEWORK
--#region CRAFTING FRAMEWORK

local CraftingFramework = include("CraftingFramework")
if not CraftingFramework then return end

local enterVehicle = {
    text = "Get in/out",
    callback = function(e)
        CPlayerSteerManager.getInstance():OnActivate(e.reference)
    end
}

local destroyVehicle = {
    text = "Destroy",
    callback = function(e)
        CPlayerSteerManager.getInstance():OnDestroy(e.reference)
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
    local class = interop.getVehicleData(id)
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
                CPlayerSteerManager.getInstance():OnActivate(e.reference)
            end
        }

        return recipe
    end
    return nil
end

---@diagnostic disable-next-line: undefined-doc-name
---@type CraftingFramework.Recipe.data[]
local recipes = {}
local mounts = interop.vehicles
for _, id in ipairs(mounts) do
    local r = getRecipeFor(id)
    if r then
        table.insert(recipes, r)
    end
end

local function registerRecipes(e)
    if e.menuActivator then e.menuActivator:registerRecipes(recipes) end
end
event.register("Ashfall:ActivateBushcrafting:Registered", registerRecipes)

--#endregion

--[[

-- boats

Mount a_gondola_01
  Bounding Box min: (-71.20,-356.43,-86.24)
  Bounding Box max: (71.20,356.43,86.24)
Mount a_mushroomdola_iv
  Bounding Box min: (-192.74,-332.32,-86.24)
  Bounding Box max: (183.23,453.84,223.41)
Mount a_rowboat_iv
  Bounding Box min: (-67.72,-175.68,-36.73)
  Bounding Box max: (67.75,179.42,36.73)
Mount a_sailboat_iv
  Bounding Box min: (-108.11,-320.38,-74.86)
  Bounding Box max: (210.41,444.66,809.85)
Mount a_telvcatboat_iv
  Bounding Box min: (-283.74,-908.30,-282.73)
  Bounding Box max: (225.16,830.83,658.28)


-- creatures

Mount a_cliffracer
  Bounding Box min: (-205.65,-420.28,-67.17)
  Bounding Box max: (205.41,41.53,251.36)
Mount a_nix-hound
  Bounding Box min: (-75.46,-230.34,-34.39)
  Bounding Box max: (135.54,11.85,161.92)

]]
