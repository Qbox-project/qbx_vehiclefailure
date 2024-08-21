local pedInSameVehicleLast = false
local vehicle
local lastVehicle
local vehicleClass
local fCollisionDamageMult = 0.0
local fDeformationDamageMult = 0.0
local fEngineDamageMult = 0.0
local fBrakeForce = 1.0
local isBrakingForward = false
local isBrakingReverse = false
local healthEngineLast = 1000.0
local healthEngineCurrent = 1000.0
local healthEngineNew = 1000.0
local healthEngineDelta = 0.0
local healthEngineDeltaScaled = 0.0
local healthBodyLast = 1000.0
local healthBodyCurrent = 1000.0
local healthBodyNew = 1000.0
local healthBodyDelta = 0.0
local healthBodyDeltaScaled = 0.0
local healthPetrolTankLast = 1000.0
local healthPetrolTankCurrent = 1000.0
local healthPetrolTankNew = 1000.0
local healthPetrolTankDelta = 0.0
local healthPetrolTankDeltaScaled = 0.0
local fixMessagePos = math.random(repairCfg.fixMessageCount)
local noFixMessagePos = math.random(repairCfg.noFixMessageCount)
local tireBurstMaxNumber = cfg.randomTireBurstInterval * 1200;
local DamageComponents = {
    'radiator',
    'axle',
    'clutch',
    'fuel',
    'brakes',
}

-- Functions

local function damageRandomComponent()
    local dmgFctr = math.random() + math.random(0, 2)
    local randomComponent = DamageComponents[math.random(1, #DamageComponents)]
    local randomDamage = (math.random() + math.random(0, 1)) * dmgFctr
    exports.qbx_mechanicjob:SetVehicleStatus(qbx.getVehiclePlate(vehicle), randomComponent, exports.qbx_mechanicjob:GetVehicleStatus(qbx.getVehiclePlate(vehicle), randomComponent) - randomDamage)
end

---cleans vehicle with animation and progress bar. Consumes a cleaning kit.
---@param veh number
local function cleanVehicle(veh)
    TaskStartScenarioInPlace(cache.ped, 'WORLD_HUMAN_MAID_CLEAN', 0, true)
    if lib.progressBar({
        duration = math.random(10000, 20000),
        label = locale('progress.clean_veh'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true
        }
    }) then -- if completed
        exports.qbx_core:Notify(locale('success.cleaned_veh'))
        SetVehicleDirtLevel(veh, 0.1)
        SetVehicleUndriveable(veh, false)
        WashDecalsFromVehicle(veh, 1.0)
        TriggerServerEvent('qb-vehiclefailure:server:removewashingkit', veh)
        ClearAllPedProps(cache.ped)
        ClearPedTasks(cache.ped)
    else -- if canceled
        exports.qbx_core:Notify(locale('error.failed_notification'), 'error')
        ClearAllPedProps(cache.ped)
        ClearPedTasks(cache.ped)
    end
end

---@param vehModel number
---@return boolean
local function isBackEngine(vehModel)
    if BackEngineVehicles[vehModel] then return true else return false end
end

---@param veh number
local function openVehicleDoors(veh)
    if isBackEngine(GetEntityModel(veh)) then
        SetVehicleDoorOpen(veh, 5, false, false)
    else
        SetVehicleDoorOpen(veh, 4, false, false)
    end
end

---@param veh number
local function closeVehicleDoors(veh)
    if isBackEngine(GetEntityModel(veh)) then
        SetVehicleDoorShut(veh, 5, false)
    else
        SetVehicleDoorShut(veh, 4, false)
    end
end

---@param engineHealth number
---@param itemName string
---@param timeLowerBound integer
---@param timeUpperBound integer
local function repairVehicle(veh, engineHealth, itemName, timeLowerBound, timeUpperBound)
    openVehicleDoors(veh)
    if lib.progressBar({
        duration = math.random(timeLowerBound, timeUpperBound),
        label = locale('progress.repair_veh'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_player',
            flag = 16
        }
    }) then -- if completed
        exports.qbx_core:Notify(locale('success.repaired_veh'))
        SetVehicleEngineHealth(veh, engineHealth)
        SetVehicleEngineOn(veh, true, false)
        SetVehicleTyreFixed(veh, 0)
        SetVehicleTyreFixed(veh, 1)
        SetVehicleTyreFixed(veh, 2)
        SetVehicleTyreFixed(veh, 3)
        SetVehicleTyreFixed(veh, 4)
        closeVehicleDoors(veh)
        TriggerServerEvent('qb-vehiclefailure:removeItem', itemName)
    else -- if canceled
        exports.qbx_core:Notify(locale('error.failed_notification'), 'error')
        closeVehicleDoors(veh)
    end
end

---repairs vehicle with progress bar and animation, consuming an advanced repair kit.
---@param veh number
local function repairVehicleFull(veh)
    repairVehicle(veh, 1000, 'advancedrepairkit', 20000, 30000)
end

---repairs tires and engine to half health with progress bar and animation. Consumes a repair kit.
---@param veh number
local function repairVehicleHalf(veh)
    repairVehicle(veh, 500, 'repairkit', 10000, 20000)
end

---@return boolean isDriver if ped is driving an automobile or motorcycle
local function isPedDrivingAVehicle()
    if cache.seat ~= -1 then
        return false
    end

    local class = GetVehicleClass(cache.vehicle)
    -- We don't want planes, helicopters, bicycles and trains
    if class == 15 or class == 16 or class == 21 or class == 13 then
        return false
    end

    return true
end

---@return boolean?
local function isNearMechanic()
    local pedLocation = GetEntityCoords(cache.ped, 0)
    for _, item in pairs(repairCfg.mechanics) do
        local distance = #(vector3(item.x, item.y, item.z) - pedLocation)
        if distance <= item.r then
            return true
        end
    end
end

---@param inputValue number
---@param originalMin number
---@param originalMax number
---@param newBegin number
---@param newEnd number
---@param curve number
---@return number
local function fscale(inputValue, originalMin, originalMax, newBegin, newEnd, curve)
    local originalRange
    local newRange
    local zeroRefCurVal
    local normalizedCurVal
    local rangedValue
    local invFlag = 0

    if (curve > 10.0) then curve = 10.0 end
    if (curve < -10.0) then curve = -10.0 end

    curve = (curve * -.1)
    curve = 10.0 ^ curve

    if (inputValue < originalMin) then
        inputValue = originalMin
    end
    if inputValue > originalMax then
        inputValue = originalMax
    end

    originalRange = originalMax - originalMin

    if (newEnd > newBegin) then
        newRange = newEnd - newBegin
    else
        newRange = newBegin - newEnd
        invFlag = 1
    end

    zeroRefCurVal = inputValue - originalMin
    normalizedCurVal  =  zeroRefCurVal / originalRange

    if (originalMin > originalMax ) then
        return 0
    end

    if (invFlag == 0) then
        rangedValue =  ((normalizedCurVal ^ curve) * newRange) + newBegin
    else
        rangedValue =  newBegin - ((normalizedCurVal ^ curve) * newRange)
    end

    return rangedValue
end

---rolls a die and bursts a single tire if die hits.
local function tireBurstLottery()
    local tireBurstNumber = math.random(tireBurstMaxNumber)
    if tireBurstNumber ~= tireBurstMaxNumber then return end

    -- We won the lottery, lets burst a tire.
    if GetVehicleTyresCanBurst(vehicle) == false then return end
    local numWheels = GetVehicleNumberOfWheels(vehicle)
    local affectedTire
    if numWheels == 2 then
        affectedTire = (math.random(2) - 1) * 4		-- wheel 0 or 4
    elseif numWheels == 4 then
        affectedTire = (math.random(4) - 1)
        if affectedTire > 1 then affectedTire = affectedTire + 2 end	-- 0, 1, 4, 5
    elseif numWheels == 6 then
        affectedTire = (math.random(6) - 1)
    else
        affectedTire = 0
    end
    SetVehicleTyreBurst(vehicle, affectedTire, false, 1000.0)
end

---@return number? veh
local function getVehicleToRepair()
    if cache.vehicle then
        exports.qbx_core:Notify(locale('error.inside_veh'), 'error')
        return
    end

    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5, false)
    if not veh then
        exports.qbx_core:Notify(locale('error.not_near_veh'), 'error')
        return
    end

    local pos = GetEntityCoords(cache.ped)
    local drawpos = GetOffsetFromEntityInWorldCoords(veh, 0, 2.5, 0)
    if (isBackEngine(GetEntityModel(veh))) then
        drawpos = GetOffsetFromEntityInWorldCoords(veh, 0, -2.5, 0)
    end

    if #(pos - drawpos) >= 2.0 then
        return
    end

    return veh
end

RegisterNetEvent('qb-vehiclefailure:client:RepairVehicle', function()
    local veh = getVehicleToRepair()
    if not veh then return end

    local engineHealth = GetVehicleEngineHealth(veh) --This is to prevent people from 'repairing' a vehicle and setting engine health lower than what the vehicles engine health was before repairing.
    if engineHealth >= 500 then
        exports.qbx_core:Notify(locale('error.healthy_veh'), 'error')
        return
    end

    repairVehicleHalf(veh)
end)

RegisterNetEvent('qb-vehiclefailure:client:RepairVehicleFull', function()
    local veh = getVehicleToRepair()
    if not veh then return end
    repairVehicleFull(veh)
end)

---@param veh number
RegisterNetEvent('qb-vehiclefailure:client:SyncWash', function(veh)
    SetVehicleDirtLevel(veh, 0.1)
    SetVehicleUndriveable(veh, false)
    WashDecalsFromVehicle(veh, 1.0)
end)

RegisterNetEvent('qb-vehiclefailure:client:CleanVehicle', function()
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 3, false)
    if not veh then return end
    cleanVehicle(veh)
end)

RegisterNetEvent('iens:repaira', function()
    if not isPedDrivingAVehicle() then
        exports.qbx_core:Notify(locale('error.inside_veh_req'))
        return
    end
    vehicle = cache.vehicle
    SetVehicleDirtLevel(vehicle)
    SetVehicleUndriveable(vehicle, false)
    WashDecalsFromVehicle(vehicle, 1.0)
    exports.qbx_core:Notify(locale('success.repaired_veh'))
    SetVehicleFixed(vehicle)
    healthBodyLast = 1000.0
    healthEngineLast = 1000.0
    healthPetrolTankLast = 1000.0
    SetVehicleEngineOn(vehicle, true, false)
end)

RegisterNetEvent('iens:besked', function()
    exports.qbx_core:Notify(locale('error.roadside_avail'))
end)

RegisterNetEvent('iens:notAllowed', function()
    exports.qbx_core:Notify(locale('error.no_permission'))
end)

RegisterNetEvent('iens:repair', function()
    if not isPedDrivingAVehicle() then
        exports.qbx_core:Notify(locale('error.inside_veh_req'))
        return
    end
    vehicle = cache.vehicle
    if isNearMechanic() then return end
    if GetVehicleEngineHealth(vehicle) >= cfg.cascadingFailureThreshold + 5 then
        exports.qbx_core:Notify(locale(('error.nofix_message_%s'):format(noFixMessagePos)))
        noFixMessagePos += 1
        if noFixMessagePos > repairCfg.noFixMessageCount then noFixMessagePos = 1 end
        return
    end
    if GetVehicleOilLevel(vehicle) <= 0 then
        exports.qbx_core:Notify(locale('error.veh_damaged'))
        return
    end

    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineHealth(vehicle, cfg.cascadingFailureThreshold + 5)
    SetVehiclePetrolTankHealth(vehicle, 750.0)
    healthEngineLast = cfg.cascadingFailureThreshold + 5
    healthPetrolTankLast = 750.0
    SetVehicleEngineOn(vehicle, true, false )
    SetVehicleOilLevel(vehicle, (GetVehicleOilLevel(vehicle) / 3) - 0.5)
    exports.qbx_core:Notify(locale(('success.fix_message_%s'):format(fixMessagePos)))
    fixMessagePos += 1
    if fixMessagePos > repairCfg.fixMessageCount then fixMessagePos = 1 end
end)

-- Threads

if cfg.displayBlips then
    CreateThread(function()
        for _, item in pairs(repairCfg.mechanics) do
            item.blip = AddBlipForCoord(item.x, item.y, item.z)
            SetBlipSprite(item.blip, item.id)
            SetBlipScale(item.blip, 0.8)
            SetBlipAsShortRange(item.blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(item.name)
            EndTextCommandSetBlipName(item.blip)
        end
    end)
end

local function preventVehicleFlip()
    local roll = GetEntityRoll(vehicle)
    if (roll > 75.0 or roll < -75.0) and GetEntitySpeed(vehicle) < 2 then
        DisableControlAction(2, 59, true) -- Disable left/right
        DisableControlAction(2, 60, true) -- Disable up/down
    end
end

local function preventAirControl()
    local veh = cache.vehicle
    if not veh or IsEntityDead(veh) then return end
    local model = GetEntityModel(veh)
    -- If it's not a boat, plane or helicopter, and the vehicle is off the ground with ALL wheels, then block steering/leaning left/right/up/down.
    if IsThisModelABoat(model) or IsThisModelAHeli(model) or IsThisModelAPlane(model) or not IsEntityInAir(veh) then return end
    DisableControlAction(0, 59, true)
    DisableControlAction(0, 61, true)
    DisableControlAction(0, 62, true)
end

local function setVehicleEngineTorqueMultiplier()
    local factor = 1.0
    if cfg.torqueMultiplierEnabled and healthEngineNew < 900 then
        factor = (healthEngineNew + 200.0) / 1100
    end
    if cfg.sundayDriver and GetVehicleClass(vehicle) ~= 14 then -- Not for boats
        local accelerator = GetControlValue(2, 71)
        local brake = GetControlValue(2, 72)
        local speed = GetEntitySpeedVector(vehicle, true)['y']
        -- Change Braking force
        local brk = fBrakeForce
        if speed >= 1.0 then
            -- Going forward
            if accelerator > 127 then
                -- Forward and accelerating
                local acc = fscale(accelerator, 127.0, 254.0, 0.1, 1.0, 10.0 - (cfg.sundayDriverAcceleratorCurve * 2.0))
                factor = factor * acc
            end
            if brake > 127 then
                -- Forward and braking
                isBrakingForward = true
                brk = fscale(brake, 127.0, 254.0, 0.01, fBrakeForce, 10.0 - (cfg.sundayDriverBrakeCurve * 2.0))
                --exports['qb-vehicletuning']:SetVehicleStatus(qbx.getVehiclePlate(vehicle), 'brakes', exports['qb-vehicletuning']:GetVehicleStatus(qbx.getVehiclePlate(vehicle), 'brakes') - 0.01)
            end
        elseif speed <= -1.0 then
            -- Going reverse
            if brake > 127 then
                -- Reversing and accelerating (using the brake)
                local rev = fscale(brake, 127.0, 254.0, 0.1, 1.0, 10.0 - (cfg.sundayDriverAcceleratorCurve * 2.0))
                factor = factor * rev
                --exports['qb-vehicletuning']:SetVehicleStatus(qbx.getVehiclePlate(vehicle), 'brakes', exports['qb-vehicletuning']:GetVehicleStatus(qbx.getVehiclePlate(vehicle), 'brakes') - 0.01)
            end
            if accelerator > 127 then
                -- Reversing and braking (Using the accelerator)
                isBrakingReverse = true
                brk = fscale(accelerator, 127.0, 254.0, 0.01, fBrakeForce, 10.0 - (cfg.sundayDriverBrakeCurve * 2.0))
            end
        else
            -- Stopped or almost stopped or sliding sideways
            local entitySpeed = GetEntitySpeed(vehicle)
            if entitySpeed < 1 then
                -- Not sliding sideways
                if isBrakingForward == true then
                    --Stopped or going slightly forward while braking
                    DisableControlAction(2, 72, true) -- Disable Brake until user lets go of brake
                    SetVehicleForwardSpeed(vehicle, speed * 0.98)
                    SetVehicleBrakeLights(vehicle, true)
                end
                if isBrakingReverse == true then
                    --Stopped or going slightly in reverse while braking
                    DisableControlAction(2, 71, true) -- Disable reverse Brake until user lets go of reverse brake (Accelerator)
                    SetVehicleForwardSpeed(vehicle, speed * 0.98)
                    SetVehicleBrakeLights(vehicle, true)
                end
                if isBrakingForward == true and GetDisabledControlNormal(2, 72) == 0 then
                    -- We let go of the brake
                    isBrakingForward = false
                end
                if isBrakingReverse == true and GetDisabledControlNormal(2, 71) == 0 then
                    -- We let go of the reverse brake (Accelerator)
                    isBrakingReverse = false
                end
            end
        end
        if brk > fBrakeForce - 0.02 then brk = fBrakeForce end -- Make sure we can brake max.
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', brk)  -- Set new Brake Force multiplier
    end
    if cfg.limpMode == true and healthEngineNew < cfg.engineSafeGuard + 5 then
        factor = cfg.limpModeMultiplier
    end
    SetVehicleEngineTorqueMultiplier(vehicle, factor)
end

local function vehicleModThread()
    CreateThread(function()
        while cache.seat == -1 do
            Wait(0)
            if cfg.torqueMultiplierEnabled or cfg.sundayDriver or cfg.limpMode then
                if pedInSameVehicleLast then
                    setVehicleEngineTorqueMultiplier()
                end
            end
            if cfg.preventVehicleFlip then
                preventVehicleFlip()
            end
            if cfg.preventAirControl then
                preventAirControl()
            end
        end
    end)
end

if cfg.torqueMultiplierEnabled or cfg.preventVehicleFlip or cfg.limpMode or cfg.preventAirControl then
    lib.onCache('seat', function(value)
        if not value or value ~= -1 then return end
        vehicleModThread()
    end)
end

CreateThread(function()
    while true do
        Wait(50)
        if cache.seat == -1 then
            vehicle = cache.vehicle
            vehicleClass = GetVehicleClass(vehicle)
            healthEngineCurrent = GetVehicleEngineHealth(vehicle)
            if healthEngineCurrent == 1000 then healthEngineLast = 1000.0 end
            healthEngineNew = healthEngineCurrent
            healthEngineDelta = healthEngineLast - healthEngineCurrent
            healthEngineDeltaScaled = healthEngineDelta * cfg.damageFactorEngine * cfg.classDamageMultiplier[vehicleClass]

            healthBodyCurrent = GetVehicleBodyHealth(vehicle)
            if healthBodyCurrent == 1000 then healthBodyLast = 1000.0 end
            healthBodyNew = healthBodyCurrent
            healthBodyDelta = healthBodyLast - healthBodyCurrent
            healthBodyDeltaScaled = healthBodyDelta * cfg.damageFactorBody * cfg.classDamageMultiplier[vehicleClass]

            healthPetrolTankCurrent = GetVehiclePetrolTankHealth(vehicle)
            if cfg.compatibilityMode and healthPetrolTankCurrent < 1 then
                --	SetVehiclePetrolTankHealth(vehicle, healthPetrolTankLast)
                --	healthPetrolTankCurrent = healthPetrolTankLast
                healthPetrolTankLast = healthPetrolTankCurrent
            end
            if healthPetrolTankCurrent == 1000 then healthPetrolTankLast = 1000.0 end
            healthPetrolTankNew = healthPetrolTankCurrent
            healthPetrolTankDelta = healthPetrolTankLast-healthPetrolTankCurrent
            healthPetrolTankDeltaScaled = healthPetrolTankDelta * cfg.damageFactorPetrolTank * cfg.classDamageMultiplier[vehicleClass]

            if healthEngineCurrent > cfg.engineSafeGuard + 1 then
                SetVehicleUndriveable(vehicle,false)
            end

            if healthEngineCurrent <= cfg.engineSafeGuard + 1 and cfg.limpMode == false then
                local vehpos = GetEntityCoords(vehicle)
                StartParticleFxLoopedAtCoord('ent_ray_heli_aprtmnt_l_fire', vehpos.x, vehpos.y, vehpos.z - 0.7, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
                SetVehicleUndriveable(vehicle, true)
            end

            -- If ped spawned a new vehicle while in a vehicle or teleported from one vehicle to another, handle as if we just entered the car
            if vehicle ~= lastVehicle then
                pedInSameVehicleLast = false
            end


            if pedInSameVehicleLast == true then
                -- Damage happened while in the car = can be multiplied

                -- Only do calculations if any damage is present on the car. Prevents weird behavior when fixing using trainer or other script
                if healthEngineCurrent ~= 1000.0 or healthBodyCurrent ~= 1000.0 or healthPetrolTankCurrent ~= 1000.0 then

                    -- Combine the delta values (Get the largest of the three)
                    local healthEngineCombinedDelta = math.max(healthEngineDeltaScaled, healthBodyDeltaScaled, healthPetrolTankDeltaScaled)

                    -- If huge damage, scale back a bit
                    if healthEngineCombinedDelta > (healthEngineCurrent - cfg.engineSafeGuard) then
                        healthEngineCombinedDelta = healthEngineCombinedDelta * 0.7
                    end

                    -- If complete damage, but not catastrophic (ie. explosion territory) pull back a bit, to give a couple of seconds og engine runtime before dying
                    if healthEngineCombinedDelta > healthEngineCurrent then
                        healthEngineCombinedDelta = healthEngineCurrent - (cfg.cascadingFailureThreshold / 5)
                    end


                    ------- Calculate new value

                    healthEngineNew = healthEngineLast - healthEngineCombinedDelta


                    ------- Sanity Check on new values and further manipulations

                    -- If somewhat damaged, slowly degrade until slightly before cascading failure sets in, then stop

                    if healthEngineNew > (cfg.cascadingFailureThreshold + 5) and healthEngineNew < cfg.degradingFailureThreshold then
                        healthEngineNew = healthEngineNew - (0.038 * cfg.degradingHealthSpeedFactor)
                    end

                    -- If Damage is near catastrophic, cascade the failure
                    if healthEngineNew < cfg.cascadingFailureThreshold then
                        healthEngineNew = healthEngineNew - (0.1 * cfg.cascadingFailureSpeedFactor)
                    end

                    -- Prevent Engine going to or below zero. Ensures you can reenter a damaged car.
                    if healthEngineNew < cfg.engineSafeGuard then
                        healthEngineNew = cfg.engineSafeGuard
                    end

                    -- Prevent Explosions
                    if cfg.compatibilityMode == false and healthPetrolTankCurrent < 750 then
                        healthPetrolTankNew = 750.0
                    end

                    -- Prevent negative body damage.
                    if healthBodyNew < 0  then
                        healthBodyNew = 0.0
                    end
                end
            else
                -- Just got in the vehicle. Damage can not be multiplied this round
                -- Set vehicle handling data
                fDeformationDamageMult = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDeformationDamageMult')
                fBrakeForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce')
                local newFDeformationDamageMult = fDeformationDamageMult ^ cfg.deformationExponent	-- Pull the handling file value closer to 1
                if cfg.deformationMultiplier ~= -1 then SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDeformationDamageMult', newFDeformationDamageMult * cfg.deformationMultiplier) end  -- Multiply by our factor
                if cfg.weaponsDamageMultiplier ~= -1 then SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fWeaponDamageMult', cfg.weaponsDamageMultiplier / cfg.damageFactorBody) end -- Set weaponsDamageMultiplier and compensate for damageFactorBody

                --Get the CollisionDamageMultiplier
                fCollisionDamageMult = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fCollisionDamageMult')
                --Modify it by pulling all number a towards 1.0
                local newFCollisionDamageMultiplier = fCollisionDamageMult ^ cfg.collisionDamageExponent	-- Pull the handling file value closer to 1
                SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fCollisionDamageMult', newFCollisionDamageMultiplier)

                --Get the EngineDamageMultiplier
                fEngineDamageMult = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fEngineDamageMult')
                --Modify it by pulling all number a towards 1.0
                local newFEngineDamageMult = fEngineDamageMult ^ cfg.engineDamageExponent	-- Pull the handling file value closer to 1
                SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fEngineDamageMult', newFEngineDamageMult)

                -- If body damage catastrophic, reset somewhat so we can get new damage to multiply
                if healthBodyCurrent < cfg.cascadingFailureThreshold then
                    healthBodyNew = cfg.cascadingFailureThreshold
                end
                pedInSameVehicleLast = true
            end

            -- set the actual new values
            if healthEngineNew ~= healthEngineCurrent then
                SetVehicleEngineHealth(vehicle, healthEngineNew)
                local dmgFactr = (healthEngineCurrent - healthEngineNew)
                if dmgFactr > 0.8 then
                    damageRandomComponent()
                end
            end
            if healthBodyNew ~= healthBodyCurrent then
                SetVehicleBodyHealth(vehicle, healthBodyNew)
                damageRandomComponent()
            end
            if healthPetrolTankNew ~= healthPetrolTankCurrent then
                SetVehiclePetrolTankHealth(vehicle, healthPetrolTankNew)
            end

            -- Store current values, so we can calculate delta next time around
            healthEngineLast = healthEngineNew
            healthBodyLast = healthBodyNew
            healthPetrolTankLast = healthPetrolTankNew
            lastVehicle = vehicle
            if cfg.randomTireBurstInterval ~= 0 and GetEntitySpeed(vehicle) > 10 then tireBurstLottery() end
        else
            if pedInSameVehicleLast == true then
                -- We just got out of the vehicle
                lastVehicle = GetVehiclePedIsIn(cache.ped, true)
                if cfg.deformationMultiplier ~= -1 then SetVehicleHandlingFloat(lastVehicle, 'CHandlingData', 'fDeformationDamageMult', fDeformationDamageMult) end -- Restore deformation multiplier
                SetVehicleHandlingFloat(lastVehicle, 'CHandlingData', 'fBrakeForce', fBrakeForce)  -- Restore Brake Force multiplier
                if cfg.weaponsDamageMultiplier ~= -1 then SetVehicleHandlingFloat(lastVehicle, 'CHandlingData', 'fWeaponDamageMult', cfg.weaponsDamageMultiplier) end	-- Since we are out of the vehicle, we should no longer compensate for bodyDamageFactor
                SetVehicleHandlingFloat(lastVehicle, 'CHandlingData', 'fCollisionDamageMult', fCollisionDamageMult) -- Restore the original CollisionDamageMultiplier
                SetVehicleHandlingFloat(lastVehicle, 'CHandlingData', 'fEngineDamageMult', fEngineDamageMult) -- Restore the original EngineDamageMultiplier
            end
            pedInSameVehicleLast = false
        end
    end
end)
