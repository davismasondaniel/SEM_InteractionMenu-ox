--[[
──────────────────────────────────────────────────────────────

	SEM_InteractionMenu (client.lua) - Created by Scott M
	Current Version: v1.7.1 (Sep 2021)
	
	Support: https://semdevelopment.com/discord
	
		!!! Change vaules in the 'config.lua' !!!
	DO NOT EDIT THIS IF YOU DON'T KNOW WHAT YOU ARE DOING

──────────────────────────────────────────────────────────────
]]



--Cuffing Event
local isCuffed = false
RegisterNetEvent('SEM_InteractionMenu:Cuff')
AddEventHandler('SEM_InteractionMenu:Cuff', function()
    local Ped = PlayerPedId()
    if (DoesEntityExist(Ped)) then
        CreateThread(function()
            if isCuffed then
                -- Uncuffing
                local animation = { dict = "mp_arresting", name = "b_uncuff" }
                RequestAnimDict(animation.dict)
                while not HasAnimDictLoaded(animation.dict) do
                    Wait(0)
                end
                TaskPlayAnim(Ped, animation.dict, animation.name, 8.0, -8, -1, 0, 0, 0, 0, 0)
                
                Wait(3000)
                
                isCuffed = false
                SetEnableHandcuffs(Ped, false)
                ClearPedTasksImmediately(Ped)
            else
                -- Cuffing
                isCuffed = true
                SetEnableHandcuffs(Ped, true)
                
                -- Cuffing animation
                local animation = { dict = "mp_arrest_paired", name = "crook_p2_back_right" }
                RequestAnimDict(animation.dict)
                while not HasAnimDictLoaded(animation.dict) do
                    Wait(0)
                end
                TaskPlayAnim(Ped, animation.dict, animation.name, 8.0, -8, 3750, 2, 0, 0, 0, 0)
                
                SetTimeout(3800, function()
                    if isCuffed then
                        local cuffedAnim = { dict = "mp_arresting", name = "idle" }
                        RequestAnimDict(cuffedAnim.dict)
                        while not HasAnimDictLoaded(cuffedAnim.dict) do
                            Wait(0)
                        end
                        TaskPlayAnim(Ped, cuffedAnim.dict, cuffedAnim.name, 8.0, -8, -1, 49, 0, 0, 0, 0)
                    end
                end)
                
                -- Attempt uncuffing
                Wait(4000) -- Wait 4 seconds before starting
                TriggerEvent('SEM_InteractionMenu:AttemptUncuff')
            end
        end)
    end
end)

-- Uncuff attempt event
RegisterNetEvent('SEM_InteractionMenu:AttemptUncuff')
AddEventHandler('SEM_InteractionMenu:AttemptUncuff', function()
    if isCuffed then
        if exports['ox_lib'] and exports['ox_lib'].skillCheck then
            local success = exports['ox_lib']:skillCheck({'easy', 'easy', {areaSize = 60, speedMultiplier = 2}, 'easy'}, {'w', 'a', 's', 'd'})
            if success then
                isCuffed = false
                local Ped = PlayerPedId()
                SetEnableHandcuffs(Ped, false)
                ClearPedTasksImmediately(Ped)
                lib.notify({
                    title = 'Success',
                    description = 'You have escaped cuffs!',
                    type = 'success',
                })
            else
                lib.notify({
                    title = 'Failed',
                    description = 'You failed to escape cuffs!',
                    type = 'error',
                })
            end
        else
            lib.notify({
                title = 'Error',
                description = 'Unable to attempt uncuffing. Required resource not available.',
                type = 'error',
            })
        end
    end
end)

-- Arrest animation
RegisterNetEvent('SEM_InteractionMenu:OfficerCuffAnim')
AddEventHandler('SEM_InteractionMenu:OfficerCuffAnim', function()
    local playerPed = PlayerPedId()
    local animation = {dict = 'mp_arrest_paired', name = 'cop_p2_back_right'}
    
    RequestAnimDict(animation.dict)
    while not HasAnimDictLoaded(animation.dict) do
        Wait(0)
    end
    TaskPlayAnim(playerPed, animation.dict, animation.name, 8.0, -8, 3750, 48, 0, 0, 0, 0)
end)

--Cuff Animation & Restrictions
-- Cuff Animation & Restrictions (optimized sleep)
CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()

        if isCuffed then
            sleep = 0

            if IsEntityDead(ped) then
                isCuffed = false
                SetEnableHandcuffs(ped, false)
                ClearPedTasksImmediately(ped)
            else
                if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                    RequestAnimDict("mp_arresting")
                    while not HasAnimDictLoaded("mp_arresting") do
                        Wait(50)
                    end
                    TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
                end

                SetEnableHandcuffs(ped, true)
                SetPedCanPlayGestureAnims(ped, false)
                FreezeEntityPosition(ped, false)

                SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
                
                if not Config.VehEnterCuffed then
                    DisableControlAction(1, 23, true) --F | Enter Vehicle
                    DisableControlAction(1, 75, true) --F | Exit Vehicle
                end

                DisableControlAction(1, 140, true) --R
                DisableControlAction(1, 141, true) --Q
                DisableControlAction(1, 142, true) --LMB
                SetPedPathCanUseLadders(ped, false)
                
                DisableControlAction(0, 21, true)  -- sprint
                DisableControlAction(0, 24, true)  -- attack
                DisableControlAction(0, 25, true)  -- aim
                DisableControlAction(0, 47, true)  -- weapon
                DisableControlAction(0, 58, true)  -- weapon
                DisableControlAction(0, 263, true) -- melee
                DisableControlAction(0, 264, true) -- melee
                DisableControlAction(0, 257, true) -- melee
                DisableControlAction(0, 140, true) -- melee
                DisableControlAction(0, 141, true) -- melee
                DisableControlAction(0, 142, true) -- melee
                DisableControlAction(0, 143, true) -- melee
                
                if IsPedInAnyVehicle(ped, false) then
                    DisableControlAction(0, 59, true)
                end
            end
        else
            -- Reset state when not cuffed (check occasionally, not every frame)
            SetEnableHandcuffs(ped, false)
            SetPedCanPlayGestureAnims(ped, true)
            SetPedMoveRateOverride(ped, 1.0)
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        end

        Wait(sleep)
    end
end)




--Dragging Event
local Drag = false
local OfficerDrag = -1

RegisterNetEvent('SEM_InteractionMenu:Drag')
AddEventHandler('SEM_InteractionMenu:Drag', function(ID)
    if not isCuffed and ID ~= -1 then
        lib.notify({
            title = 'Error',
            description = 'You can only drag a cuffed player!',
            type = 'error',
        })
        return
    end

    Drag = not Drag
    OfficerDrag = ID

    if not Drag then
        DetachEntity(PlayerPedId(), true, false)
    end
end)

RegisterNetEvent('SEM_InteractionMenu:OfficerDragAnim')
AddEventHandler('SEM_InteractionMenu:OfficerDragAnim', function()
    local ped = PlayerPedId()
    local anim = { dict = 'anim@move_m@prisoner_cuffed', name = 'idle' }
    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do
        Wait(0)
    end
    TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8, 2000, 48, 0, 0, 0, 0)
end)

-- Drag Attachment (optimized sleep)
CreateThread(function()
    while true do
        local sleep = 500

        if Drag and OfficerDrag ~= -1 then
            sleep = 0

            local officerPed = GetPlayerPed(GetPlayerFromServerId(OfficerDrag))
            local ped = PlayerPedId()

            if DoesEntityExist(officerPed) then
                AttachEntityToEntity(ped, officerPed, 4103, 0.35, 0.38, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                DisableControlAction(1, 140, true) --R
                DisableControlAction(1, 141, true) --Q
                DisableControlAction(1, 142, true) --LMB
            else
                -- Failsafe: detach if officer no longer exists
                Drag = false
                DetachEntity(ped, true, false)
            end
        end

        Wait(sleep)
    end
end)



--Force Seat Player Event
RegisterNetEvent('SEM_InteractionMenu:Seat')
AddEventHandler('SEM_InteractionMenu:Seat', function(Veh)
	local Pos = GetEntityCoords(PlayerPedId())
	local EntityWorld = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 20.0, 0.0)
    local RayHandle = CastRayPointToPoint(Pos.x, Pos.y, Pos.z, EntityWorld.x, EntityWorld.y, EntityWorld.z, 10, PlayerPedId(), 0)
    local _, _, _, _, VehicleHandle = GetRaycastResult(RayHandle)
    if VehicleHandle ~= nil then
		SetPedIntoVehicle(PlayerPedId(), VehicleHandle, 1)
	end
end)



--Force Unseat Player Event
RegisterNetEvent('SEM_InteractionMenu:Unseat')
AddEventHandler('SEM_InteractionMenu:Unseat', function(ID)
	local Ped = GetPlayerPed(ID)
	ClearPedTasksImmediately(Ped)
	PlayerPos = GetEntityCoords(PlayerPedId(),  true)
	local X = PlayerPos.x - 0
	local Y = PlayerPos.y - 0

    SetEntityCoords(PlayerPedId(), X, Y, PlayerPos.z)
end)



--Jail
CurrentlyJailed = false
EarlyRelease = false
OriginalJailTime = 0
RegisterNetEvent('SEM_InteractionMenu:JailPlayer')
AddEventHandler('SEM_InteractionMenu:JailPlayer', function(JailTime)
     if CurrentlyJailed then
        return
    end
    if CurrentlyHospitalized then
        return
    end

    OriginalJailTime = JailTime

    local Ped = PlayerPedId()
    if DoesEntityExist(Ped) then
        CreateThread(function()
            SetEntityCoords(Ped, Config.JailLocation.Jail.x, Config.JailLocation.Jail.y, Config.JailLocation.Jail.z)
            SetEntityHeading(Ped, Config.JailLocation.Jail.h)
            CurrentlyJailed = true

            while JailTime >= 0 and not EarlyRelease do
                SetEntityInvincible(Ped, true)
                if IsPedInAnyVehicle(Ped, false) then
					ClearPedTasksImmediately(Ped)
                end
                
                if JailTime % 30 == 0 and JailTime ~= 0 then
                    lib.notify({
                        title = 'Judge',
                        description = JailTime .. ' months until release.',
                        type = 'info'
                    })
                end

                Wait(1000)

                local Location = GetEntityCoords(Ped, true)
                local Distance = Vdist(Config.JailLocation.Jail.x, Config.JailLocation.Jail.y, Config.JailLocation.Jail.z, Location['x'], Location['y'], Location['z'])
                if Distance > 100 then
                    SetEntityCoords(Ped, Config.JailLocation.Jail.x, Config.JailLocation.Jail.y, Config.JailLocation.Jail.z)
                    SetEntityHeading(Ped, Config.JailLocation.Jail.h)
                    lib.notify({
                        title = 'Judge',
                        description = 'Don\'t try escape, its impossible',
                        type = 'error'
                    })
                end

                JailTime = JailTime - 1
            end

            if EarlyRelease then
                TriggerServerEvent('SEM_InteractionMenu:GlobalChat', {86, 96, 252}, 'Judge', GetPlayerName(PlayerId()) .. ' was released from Jail on Parole')
            else
                TriggerServerEvent('SEM_InteractionMenu:GlobalChat', {86, 96, 252}, 'Judge', GetPlayerName(PlayerId()) .. ' was released from Jail after ' .. OriginalJailTime .. ' months(s).')
            end
            SetEntityCoords(Ped, Config.JailLocation.Release.x, Config.JailLocation.Release.y, Config.JailLocation.Release.z)
            SetEntityHeading(Ped, Config.JailLocation.Release.h)
            CurrentlyJailed = false
            EarlyRelease = false
        end)
    end
end)

RegisterNetEvent('SEM_InteractionMenu:UnjailPlayer')
AddEventHandler('SEM_InteractionMenu:UnjailPlayer', function()
    EarlyRelease = true
end)

--Civilian Adverts
RegisterNetEvent('SEM_InteractionMenu:SyncAds')
AddEventHandler('SEM_InteractionMenu:SyncAds',function(Text, Name, Loc, File, ID)
    Ad(Text, Name, Loc, File, ID)
end)



--Inventory
RegisterNetEvent('SEM_InteractionMenu:InventoryResult')
AddEventHandler('SEM_InteractionMenu:InventoryResult', function(Inventory)
    Wait(5000)

    if Inventory ==  nil then
        Inventory = 'Empty'
    end

    lib.notify({
        title = 'Info',
        description = 'Inventory Items: ' .. Inventory,
        type = 'info',
    })
end)



--BAC
RegisterNetEvent('SEM_InteractionMenu:BACResult')
AddEventHandler('SEM_InteractionMenu:BACResult', function(BACLevel)
    Wait(5000)

    if BACLevel == nil then
        BACLevel = 0.00
    end

    local bacDisplay = string.format('%.2f', tonumber(BACLevel))
    if tonumber(BACLevel) < 0.08 then
        lib.notify({
            title = 'BAC Test Result',
            description = 'BAC Level: ' .. bacDisplay .. ' (Under Legal Limit)',
            type = 'success',
        })
    else
        lib.notify({
            title = 'BAC Test Result',
            description = 'BAC Level: ' .. bacDisplay .. ' (Over Legal Limit)',
            type = 'error',
        })
    end
end)




--Hospital
CurrentlyHospitalized = false
EarlyDischarge = false
OriginalHospitalTime = 0
RegisterNetEvent('SEM_InteractionMenu:HospitalizePlayer')
AddEventHandler('SEM_InteractionMenu:HospitalizePlayer', function(HospitalTime, HospitalLocation)
    if CurrentlyHospitalized then
        return
    end
    if CurrentlyJailed then
        return
    end

    OriginalHospitalTime = HospitalTime

    local Ped = PlayerPedId()
    if DoesEntityExist(Ped) then
        CreateThread(function()
            SetEntityCoords(Ped, HospitalLocation.Hospital.x, HospitalLocation.Hospital.y, HospitalLocation.Hospital.z)
            SetEntityHeading(Ped, HospitalLocation.Hospital.h)
            CurrentlyHospitalized = true

            while HospitalTime >= 0 and not EarlyDischarge do
                SetEntityInvincible(Ped, true)
                if IsPedInAnyVehicle(Ped, false) then
					ClearPedTasksImmediately(Ped)
                end
                
                if HospitalTime % 30 == 0 and HospitalTime ~= 0 then
                    TriggerEvent('chat:addMessage', {
                        multiline = true,
                        color = {86, 96, 252},
                        args = {'Doctor', HospitalTime .. ' months until release.'},
                    })
				end

                Wait(1000)

                local Location = GetEntityCoords(Ped, true)
                local Distance = Vdist(HospitalLocation.Hospital.x, HospitalLocation.Hospital.y, HospitalLocation.Hospital.z, Location['x'], Location['y'], Location['z'])
				if Distance > 30 then
                    SetEntityCoords(Ped, HospitalLocation.Hospital.x, HospitalLocation.Hospital.y, HospitalLocation.Hospital.z)
                    SetEntityHeading(Ped, HospitalLocation.Hospital.h)
					TriggerEvent('chat:addMessage', {
                        multiline = true,
                        color = {86, 96, 252},
                        args = {'Doctor', 'You cannot discharge yourself!'},
                    })
				end

                HospitalTime = HospitalTime - 1
            end

            if EarlyDischarge then
                TriggerServerEvent('SEM_InteractionMenu:GlobalChat', {86, 96, 252}, 'Doctor', GetPlayerName(PlayerId()) .. ' was discharged from Hospital early')
            else
                TriggerServerEvent('SEM_InteractionMenu:GlobalChat', {86, 96, 252}, 'Doctor', GetPlayerName(PlayerId()) .. ' was discharged from Hospital after ' .. OriginalHospitalTime .. ' months(s).')
            end
            SetEntityCoords(Ped, HospitalLocation.Release.x, HospitalLocation.Release.y, HospitalLocation.Release.z)
            SetEntityHeading(Ped, HospitalLocation.Release.h)
            CurrentlyHospitalized = false
            EarlyDischarge = false
        end)
    end
end)

RegisterNetEvent('SEM_InteractionMenu:UnhospitalizePlayer')
AddEventHandler('SEM_InteractionMenu:UnhospitalizePlayer', function()
    EarlyDischarge = true
end)


--Permissions
LEOAce = false
TriggerServerEvent('SEM_InteractionMenu:LEOPerms')
RegisterNetEvent('SEM_InteractionMenu:LEOPermsResult')
AddEventHandler('SEM_InteractionMenu:LEOPermsResult', function(Allowed)
    if Allowed then
        LEOAce = true
    else
        LEOAce = false
    end
end)

FireAce = false
TriggerServerEvent('SEM_InteractionMenu:FirePerms')
RegisterNetEvent('SEM_InteractionMenu:FirePermsResult')
AddEventHandler('SEM_InteractionMenu:FirePermsResult', function(Allowed)
    if Allowed then
        FireAce = true
    else
        FireAce = false
    end
end)

UnjailAllowed = false
TriggerServerEvent('SEM_InteractionMenu:UnjailPerms')
RegisterNetEvent('SEM_InteractionMenu:UnjailPermsResult')
AddEventHandler('SEM_InteractionMenu:UnjailPermsResult', function(Allowed)
    if Allowed then
        UnjailAllowed = true
    else
        UnjailAllowed = false
    end
end)

UnhospitalAllowed = false
TriggerServerEvent('SEM_InteractionMenu:UnhospitalPerms')
RegisterNetEvent('SEM_InteractionMenu:UnhospitalPermsResult')
AddEventHandler('SEM_InteractionMenu:UnhospitalPermsResult', function(Allowed)
    if Allowed then
        UnhospitalAllowed = true
    else
        UnhospitalAllowed = false
    end
end)

--Commands
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/clear', 'Clears all Weapons')
    TriggerEvent('chat:addSuggestion', '/cuff', 'Cuff Player', {{name = 'ID', help = 'Players Server ID'}})
    TriggerEvent('chat:addSuggestion', '/drag', 'Drag Player', {{name = 'ID', help = 'Players Server ID'}})
    TriggerEvent('chat:addSuggestion', '/dropweapon', 'Drops Weapon in Hand')
    TriggerEvent('chat:addSuggestion', '/coords', 'Shows Current Player Coords and Heading')

    if Config.Radar ~= 0 then
        TriggerEvent('chat:addSuggestion', '/radar', 'Toggle Radar Menu')
    end

    if Config.LEOAccess == 3 or Config.FireAccess == 3 then
        if Config.OndutyPSWDActive then
            TriggerEvent('chat:addSuggestion', '/onduty', 'Enable LEO/Fire Menu', {{name = 'Department', help = 'LEO or Fire'}, {name = 'Password', help = 'Onduty Password'}})
        else
            TriggerEvent('chat:addSuggestion', '/onduty', 'Enable LEO/Fire Menu', {{name = 'Department', help = 'LEO or Fire'}})
        end
    else
        TriggerEvent('chat:removeSuggestion', '/onduty')
    end
end)

LEOOnduty = false
FireOnduty = false
RegisterCommand('onduty', function(source, args, rawCommand)
    if Config.LEOAccess == 3 or Config.FireAccess == 3 then
        if Config.OndutyPSWDActive then
            if args[2] == Config.OndutyPSWD then
                local Department = args[1]:lower()
                if Department == 'leo' then
                    LEOOnduty = not LEOOnduty
                    if LEOOnduty then
                        lib.notify({
                            title = 'Info',
                            description = 'You are on duty as LEO',
                            type = 'info',
                        })
                    else
                        lib.notify({
                            title = 'Info',
                            description = 'You are no longer on duty as LEO',
                            type = 'info',
                        })
                    end
                elseif Department == 'fire' then
                    FireOnduty = not FireOnduty
                    if FireOnduty == true then
                        lib.notify({
                            title = 'Info',
                            description = 'You are on duty as a Firefighter',
                            type = 'info',
                        })
                    else
                        lib.notify({
                            title = 'Info',
                            description = 'You are no longer on duty as a Firefighter',
                            type = 'info',
                        })
                    end
                else
                    lib.notify({
                        title = 'Error',
                        description = 'Invalid Department',
                        type = 'error',
                    })
                end
            else
                lib.notify({
                    title = 'Error',
                    description = 'Incorrect Password',
                    type = 'error',
                })
            end
        else
            local Department = args[1]:lower()
            if Department == 'leo' then
                LEOOnduty = not LEOOnduty
                if LEOOnduty then
                    lib.notify({
                        title = 'Info',
                        description = 'You are on duty as LEO',
                        type = 'info',
                    })
                else
                    lib.notify({
                        title = 'Info',
                        description = 'You are no longer on duty as LEO!',
                        type = 'info',
                    })
                end
            elseif Department == 'fire' then
                FireOnduty = not FireOnduty
                if FireOnduty == true then
                    lib.notify({
                        title = 'Info',
                        description = 'You are onduty as a Firefighter',
                        type = 'info',
                    })
                else
                    lib.notify({
                        title = 'Info',
                        description = 'You are no longer on duty as a Firefighter',
                        type = 'info',
                    })
                end
            else
                lib.notify({
                    title = 'Info',
                    description = 'Invalid Department',
                    type = 'info',
                })
            end
        end
    end
end)

function IsOndutyLEO()
    return LEOOnduty
end
function IsOndutyFire()
    return FireOnduty
end

RegisterCommand('cuff', function(source, args, rawCommand)
    if LEORestrict() or FireRestrict() then
        if args[1] ~= nil then
            local ID = tonumber(args[1])
            if Config.CommandDistanceChecked then
                local localPlayer = GetPlayerFromServerId(ID)
                if GetDistance(localPlayer) < Config.CommandDistance then
                    TriggerServerEvent('SEM_InteractionMenu:CuffNear', ID)
                else
                    lib.notify({
                        title = 'Info',
                        description = 'That player is too far away',
                        type = 'info',
                    })
                end
            else
                TriggerServerEvent('SEM_InteractionMenu:CuffNear', ID)
            end
        else
            TriggerServerEvent('SEM_InteractionMenu:CuffNear', GetClosestPlayer())
        end
    else
        lib.notify({
            title = 'Error',
            description = 'Invalid Permissions!',
            type = 'error',
        })
    end
end)

RegisterCommand('drag', function(source, args, rawCommand)
    if LEORestrict() or FireRestrict() then
        if args[1] ~= nil then
            local ID = tonumber(args[1])
            if Config.CommandDistanceChecked then
                local localPlayer = GetPlayerFromServerId(ID)
                if GetDistance(localPlayer) < Config.CommandDistance then
                    TriggerServerEvent('SEM_InteractionMenu:DragNear', ID)
                else
                    lib.notify({
                        title = 'Info',
                        description = 'That player is too far away!',
                        type = 'info',
                    })
                end
            else
                TriggerServerEvent('SEM_InteractionMenu:DragNear', ID)
            end
        else
            TriggerServerEvent('SEM_InteractionMenu:DragNear', GetClosestPlayer())
        end
    else
        lib.notify({
            title = 'Error',
            description = 'Invalid Permissions',
            type = 'error',
        })
    end
end)

RegisterCommand('radar', function(source, args, rawCommand)
    if Config.Radar ~= 0 then
        if LEORestrict() or FireRestrict() then
            ToggleRadar()
        else
            lib.notify({
                title = 'Error',
                description = 'Invalid Permissions',
                type = 'error',
            })
        end
    end
end)

RegisterCommand('dropweapon', function(source, args, rawCommand)
    local CurrentWeapon = GetSelectedPedWeapon(PlayerPedId())
    SetPedDropsInventoryWeapon(PlayerPedId(), CurrentWeapon, -2.0, 0.0, 0.5, 30)
    lib.notify({
        title = 'Info',
        description = 'Weapon Dropped',
        type = 'info',
    })
end)

RegisterCommand('clear', function(source, args, rawCommand)
    SetEntityHealth(PlayerPedId(), 200)
    RemoveAllPedWeapons(PlayerPedId(), true)
    lib.notify({
        title = 'Info',
        description = 'All Weapons Cleared',
        type = 'info',
    })
end)

RegisterCommand('coords', function(source, args, rawCommand)
    local Coords = GetEntityCoords(PlayerPedId())
    local Heading = GetEntityHeading(PlayerPedId())

    TriggerEvent('chatMessage', 'Coords', {255, 255, 0}, '\nX: ' .. Coords.x .. '\nY: ' .. Coords.y .. '\nZ: ' .. Coords.z .. '\nHeading: ' .. Heading)
end)


-- ─────────────────────────────────────────────────────────────
--   ox_target LEO player interactions (cuff/drag/seat/unseat)
--   Uses addGlobalPlayer so every player ped is targeted
--   automatically. canInteract gates visibility to LEO on duty.
-- ─────────────────────────────────────────────────────────────

local function getTargetServerId(data)
    return GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
end

exports.ox_target:addGlobalPlayer({
    {
        name        = 'sem_leo_cuff',
        label       = 'Cuff / Uncuff',
        icon        = 'fas fa-handcuffs',
        distance    = 2.5,
        canInteract = function()
            return LEOOnduty
        end,
        onSelect    = function(data)
            local serverID = getTargetServerId(data)
            if not serverID or serverID == 0 then return end
            TriggerServerEvent('SEM_InteractionMenu:CuffNear', serverID)
            TriggerEvent('SEM_InteractionMenu:OfficerCuffAnim')
        end,
    },
})
