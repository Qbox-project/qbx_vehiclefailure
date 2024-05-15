lib.addCommand('fix', {help = 'Repair your vehicle (Admin Only)', restricted = 'group.admin'}, function(source)
    TriggerClientEvent('iens:repaira', source)
    TriggerClientEvent('vehiclemod:client:fixEverything', source)
end)

exports.qbx_core:CreateUseableItem('repairkit', function(source, item)
    local player = exports.qbx_core:GetPlayer(source)
    if player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('qb-vehiclefailure:client:RepairVehicle', source)
    end
end)

exports.qbx_core:CreateUseableItem('cleaningkit', function(source, item)
    local player = exports.qbx_core:GetPlayer(source)
    if player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('qb-vehiclefailure:client:CleanVehicle', source)
    end
end)

exports.qbx_core:CreateUseableItem('advancedrepairkit', function(source, item)
    local player = exports.qbx_core:GetPlayer(source)
    if player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent('qb-vehiclefailure:client:RepairVehicleFull', source)
    end
end)

RegisterNetEvent('qb-vehiclefailure:removeItem', function(item)
    local player = exports.qbx_core:GetPlayer(source)
    player.Functions.RemoveItem(item, 1)
end)

RegisterNetEvent('qb-vehiclefailure:server:removewashingkit', function(veh)
    local player = exports.qbx_core:GetPlayer(source)
    player.Functions.RemoveItem('cleaningkit', 1)
    TriggerClientEvent('qb-vehiclefailure:client:SyncWash', -1, veh)
end)
