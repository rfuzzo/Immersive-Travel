local interop = require("ImmersiveTravel.interop")
local lib = require("ImmersiveVehicles.lib")
local log = lib.log

local this = {}

---@param testpos tes3vector3
---@return boolean
local function checkIsCollision(testpos)
    -- raycast fore and aft to check boundaries
    local hitResult = tes3.rayTest({
        position = testpos,
        direction = tes3vector3.new(0, 0, -1),
        root = tes3.game.worldObjectRoot,
        maxDistance = 2048
    })

    if not hitResult then
        hitResult = tes3.rayTest({
            position = testpos,
            direction = tes3vector3.new(0, 0, -1),
            root = tes3.game.worldPickRoot,
            maxDistance = 2048
        })
    end

    -- no result means no collision
    return hitResult ~= nil
end

--- @param ref tes3reference
--- @param id string
---@return boolean
local function trySpawnBoat(ref, id)
    local data = interop.getVehicleStaticData(id)
    if not data then
        log:error("No data found for %s", id)
        return false
    end

    local refpos = ref.position
    local playerEyePositionZ = tes3.getPlayerEyePosition().z
    log:debug("Try spawning %s at position %s", id, refpos)

    -- local rotation = ref.sceneNode.worldTransform.rotation
    -- local rotation = tes3.player.sceneNode.worldTransform.rotation
    local orientation = tes3.player.orientation
    local rotation = tes3matrix33.new()
    rotation:fromEulerXYZ(orientation.x, orientation.y, orientation.z)
    -- rotate matrix 90 degrees
    rotation = rotation * tes3matrix33.new(
        0, 1, 0,
        -1, 0, 0,
        0, 0, 1
    )

    -- get bounding box
    local mesh = tes3.loadMesh(data.mesh)
    local box = mesh:createBoundingBox()
    local max = box.max
    local min = box.min

    -- go in concentric circles around ref
    for i = 1, 20, 1 do
        local radius = i * 50
        -- check in a circle around ref in 45 degree steps
        for angle = 0, 360, 45 do
            local angle_rad = math.rad(angle)

            -- test position in water
            local x = refpos.x + radius * math.cos(angle_rad)
            local y = refpos.y + radius * math.sin(angle_rad)
            local testpos = tes3vector3.new(x, y, data.offset)

            -- check angles in 45 degree steps


            -- for z = 0, 360, 45 do
            --     -- rotate matrix 45 degrees
            --     if z > 0 then
            --         rotation = rotation * tes3matrix33.new(
            --             math.cos(math.rad(z)), -math.sin(math.rad(z)), 0,
            --             math.sin(math.rad(z)), math.cos(math.rad(z)), 0,
            --             0, 0, 1
            --         )
            --     end



            local t = tes3transform:new(rotation, testpos, data.scale)

            -- test four corners of bounding box from top and X
            --- @type tes3vector3[]
            local tests = {}
            tests[1] = t * tes3vector3.new(0, 0, 0)
            tests[2] = t * tes3vector3.new(max.x, max.y, 0)
            tests[3] = t * tes3vector3.new(max.x, min.y, 0)
            tests[4] = t * tes3vector3.new(min.x, max.y, 0)
            tests[5] = t * tes3vector3.new(min.x, min.y, 0)
            tests[6] = t * tes3vector3.new(max.x, 0, 0)
            tests[7] = t * tes3vector3.new(min.x, 0, 0)
            tests[8] = t * tes3vector3.new(0, max.y, 0)
            tests[9] = t * tes3vector3.new(0, min.y, 0)
            tests[10] = t * tes3vector3.new(max.x / 2, 0, 0)
            tests[11] = t * tes3vector3.new(min.x / 2, 0, 0)


            local collision = false
            for _, test in ipairs(tests) do
                test.z = playerEyePositionZ
                -- check if a collision found
                if checkIsCollision(test) then
                    collision = true
                    break
                end
            end

            if not collision then
                -- debug
                -- local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                -- vfxRoot:detachAllChildren()

                -- for _, test in ipairs(tests) do
                --     if travelMarkerMesh then
                --         local child = travelMarkerMesh:clone()
                --         child.translation = test
                --         child.rotation = rotation
                --         child.appCulled = false
                --         vfxRoot:attachChild(child)
                --     end
                -- end
                -- vfxRoot:update()

                tes3.createReference {
                    object = id,
                    position = testpos,
                    orientation = rotation:toEulerXYZ(),
                    scale = data.scale
                }
                log:debug("\tSpawning %s at %s", id, testpos)
                return true
            end
            -- end
        end
    end

    log:debug("No suitable position found")
    tes3.messageBox("No suitable position found")
    return false
end

--- no idea why this is needed
---@param menu tes3uiElement
local function updatePurchaseButton(menu)
    timer.frame.delayOneFrame(function()
        if not menu then return end
        local button = menu:findChild("rf_id_purchase_topic")
        if not button then return end
        button.visible = true
        button.disabled = false
    end)
end

---@param menu tes3uiElement
---@param ref tes3reference
function this.createPurchaseTopic(menu, ref)
    local divider = menu:findChild("MenuDialog_divider")
    local topicsList = divider.parent
    local button = topicsList:createTextSelect({
        id = "rf_id_purchase_topic",
        text = "Purchase"
    })
    button.widthProportional = 1.0
    button.visible = true
    button.disabled = false

    topicsList:reorderChildren(divider, button, 1)

    button:register("mouseClick", function()
        local buttons = {}

        for id, className in pairs(interop.vehicles) do
            log:debug("Checking %s", id)

            local class = interop.getVehicleStaticData(id)
            if not class then
                goto continue
            end
            local data = class.userData
            if not data then
                goto continue
            end

            log:debug("Found %s", data.name)

            -- check if data is a boat
            -- TODO add other mounts
            if class.freedomtype == "boat" then
                local buttonText = string.format("Buy %s for %s gold", data.name, data.price)
                table.insert(buttons, {
                    text = buttonText,
                    callback = function(e)
                        -- check gold
                        local goldCount = tes3.getPlayerGold()
                        if data.price and goldCount < data.price then
                            tes3.messageBox("You don't have enough gold")
                            return
                        end

                        local success = tes3.payMerchant({ merchant = ref.mobile, cost = data.price })
                        if success then
                            if trySpawnBoat(ref, id) then
                                tes3.messageBox("You bought a new boat!")
                            end
                        else
                            tes3.messageBox("You don't have enough gold")
                        end

                        tes3ui.leaveMenuMode()
                    end,
                })
            end
            ::continue::
        end

        log:debug("Showing purchase menu with %s buttons", #buttons)
        tes3ui.showMessageMenu({ message = "Purchase a mount", buttons = buttons, cancels = true })
    end)
    menu:registerAfter("update", function() updatePurchaseButton(menu) end)
end

return this
