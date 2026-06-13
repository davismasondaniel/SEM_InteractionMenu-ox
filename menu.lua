--[[
───────────────────────────────────────────────────────────────

    SEM_InteractionMenu (menu.lua) - ox_lib version
    Original resource by Scott M (SEM Development)
    NativeUI menu fully migrated to ox_lib context menus.

───────────────────────────────────────────────────────────────
]]

local Zone, Area -- traffic manager speed zone handle & blip
local TMSize = 10.0
local TMSpeed = 0.0

local function getMenuTitle()
    if Config.MenuTitle == 1 then
        return GetPlayerName(PlayerId())
    elseif Config.MenuTitle == 2 and Config.MenuTitleCustom and Config.MenuTitleCustom ~= '' then
        return Config.MenuTitleCustom
    end

    return 'Interaction Menu'
end

local function getMenuSubtitle()
    local name = GetCurrentResourceName()
    local version = GetResourceMetadata(name, 'version', 0) or ''
    if version ~= '' then
        return name .. ' ' .. version
    end
    return name
end

local function teleportToCoords(coords)
    if not coords then return end

    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z)
    if coords.h then
        SetEntityHeading(ped, coords.h)
    end
end

local function ensureInVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        lib.notify({
            title = 'Error',
            description = 'You are not in a vehicle',
            type = 'error',
        })
        return nil
    end
    return veh
end

local function toggleVehicleEngine()
    local veh = ensureInVehicle()
    if not veh then return end

    if GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then
        lib.notify({
            title = 'Info',
            description = 'You must be in the driver seat!',
            type = 'info',
        })
        return
    end

    local isOn = GetIsVehicleEngineRunning(veh)
    SetVehicleEngineOn(veh, not isOn, false, true)
end

local function toggleInteriorLight()
    local veh = ensureInVehicle()
    if not veh then return end

    local current = IsVehicleInteriorLightOn(veh)
    SetVehicleInteriorlight(veh, not current)
end

local function changeSeat()
    local veh = ensureInVehicle()
    if not veh then return end

    local input = lib.inputDialog('Change Seat', {
        { type = 'number', label = 'Seat index (-1 = driver, 0 = passenger, 1/2 = rear)', default = 0, min = -1, max = 2 }
    })

    if not input or not input[1] then return end

    local ped = PlayerPedId()
    local seatIndex = tonumber(input[1]) or 0

    if IsVehicleSeatFree(veh, seatIndex) then
        SetPedIntoVehicle(ped, veh, seatIndex)
    else
        lib.notify({
            title = 'Info',
            description = 'That seat is not free',
            type = 'info',
        })
    end
end

local function toggleWindowByIndex(veh, index)
    if not IsVehicleWindowIntact(veh, index) then
        -- treat broken / down window as open and roll it up
        RollUpWindow(veh, index)
    else
        RollDownWindow(veh, index)
    end
end

local function handleWindows(which)
    local veh = ensureInVehicle()
    if not veh then return end

    if which == 'front' then
        toggleWindowByIndex(veh, 0)
        toggleWindowByIndex(veh, 1)
    elseif which == 'rear' then
        toggleWindowByIndex(veh, 2)
        toggleWindowByIndex(veh, 3)
    elseif which == 'all' then
        for i = 0, 3 do
            toggleWindowByIndex(veh, i)
        end
    end
end

local function toggleDoorByIndex(veh, index)
    if GetVehicleDoorAngleRatio(veh, index) > 0.1 then
        SetVehicleDoorShut(veh, index, false)
    else
        SetVehicleDoorOpen(veh, index, false, false)
    end
end

local function handleDoors(which)
    local veh = ensureInVehicle()
    if not veh then return end

    if which == 'driver' then
        toggleDoorByIndex(veh, 0)
    elseif which == 'passenger' then
        toggleDoorByIndex(veh, 1)
    elseif which == 'rear_right' then
        toggleDoorByIndex(veh, 2)
    elseif which == 'rear_left' then
        toggleDoorByIndex(veh, 3)
    elseif which == 'hood' then
        toggleDoorByIndex(veh, 4)
    elseif which == 'trunk' then
        toggleDoorByIndex(veh, 5)
    elseif which == 'all' then
        for i = 0, 5 do
            toggleDoorByIndex(veh, i)
        end
    end
end

local function repairVehicle()
    local veh = ensureInVehicle()
    if not veh then return end

    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleFixed(veh)

    lib.notify({
        title = 'Info',
        description = 'Vehicle repaired',
        type = 'info',
    })
end

local function cleanVehicle()
    local veh = ensureInVehicle()
    if not veh then return end

    SetVehicleDirtLevel(veh, 0.0)
    lib.notify({
        title = 'Info',
        description = 'Vehicle cleaned',
        type = 'info',
    })
end

local function deleteVehicle()
    if not IsPedSittingInAnyVehicle(PlayerPedId()) then
        lib.notify({
            title = 'Error',
            description = 'You are not in a vehicle',
            type = 'error',
        })
        return
    end

    local veh = GetVehiclePedIsIn(PlayerPedId(), false)

    if GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then
        lib.notify({
            title = 'Info',
            description = 'You must be in the driver seat!',
            type = 'info',
        })
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    DeleteCurrentVehicle(veh)

    if DoesEntityExist(veh) then
        lib.notify({
            title = 'Error',
            description = 'Unable to delete vehicle, please try again!',
            type = 'error',
        })
    else
        lib.notify({
            title = 'Success',
            description = 'Vehicle deleted',
            type = 'success',
        })
    end
end

local function createSpeedZone()
    if Zone then
        lib.notify({
            title = 'Info',
            description = 'You already have a speed zone created',
            type = 'info',
        })
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    Zone = AddSpeedZoneForCoord(coords.x, coords.y, coords.z, TMSize, TMSpeed, false)
    Area = AddBlipForRadius(coords.x, coords.y, coords.z, TMSize)
    SetBlipAlpha(Area, 100)

    lib.notify({
        title = 'Info',
        description = 'Speed zone created',
        type = 'info',
    })
end

local function deleteSpeedZone()
    if not Zone then
        lib.notify({
            title = 'Info',
            description = 'You do not have a speed zone set',
            type = 'info',
        })
        return
    end

    RemoveSpeedZone(Zone)
    if Area then RemoveBlip(Area) end
    Zone = nil
    Area = nil

    lib.notify({
        title = 'Info',
        description = 'Speed zone deleted',
        type = 'info',
    })
end

--============================--
--         LEO MENUS          --
--============================--

local function leoActionsContext()
    local options = {}

    table.insert(options, {
        title = 'Cuff',
        description = 'Cuff/Uncuff the closest player',
        onSelect = function()
            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:CuffNear', player)
                TriggerEvent('SEM_InteractionMenu:OfficerCuffAnim')
            end
        end
    })

    table.insert(options, {
        title = 'Drag',
        description = 'Drag/Undrag the closest player',
        onSelect = function()
            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:DragNear', player)
            end
        end
    })

    table.insert(options, {
        title = 'Seat',
        description = 'Place a player in the closest vehicle',
        onSelect = function()
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, true)
            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:SeatNear', player, veh)
            end
        end
    })

    table.insert(options, {
        title = 'Unseat',
        description = 'Remove a player from the closest vehicle',
        onSelect = function()
            if IsPedInAnyVehicle(PlayerPedId(), true) then
                lib.notify({
                    title = 'Info',
                    description = 'You need to be outside of the vehicle',
                    type = 'info',
                })
                return
            end

            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:UnseatNear', player)
            end
        end
    })

    if Config.Radar ~= 0 then
        table.insert(options, {
            title = 'Radar',
            description = 'Toggle the radar menu',
            onSelect = function()
                ToggleRadar()
            end
        })
    end

    table.insert(options, {
        title = 'Inventory Search',
        description = 'Search the closest player\'s inventory',
        onSelect = function()
            local player = GetClosestPlayer()
            if player ~= false then
                Notify('~b~Searching ...')
                TriggerServerEvent('SEM_InteractionMenu:InventorySearch', player)
            end
        end
    })

    table.insert(options, {
        title = 'BAC Test',
        description = 'Test the BAC level of the closest player',
        onSelect = function()
            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:BACTest', player)
            end
        end
    })

    if Config.LEOJail then
        table.insert(options, {
            title = 'Jail',
            description = 'Jail a player',
            onSelect = function()
                local chargesOptions = {
                    { label = 'Assault', value = 'Assault' },
                    { label = 'Battery', value = 'Battery' },
                    { label = 'Burglary', value = 'Burglary' },
                    { label = 'Drug Possession', value = 'Drug Possession' },
                    { label = 'DUI', value = 'DUI' },
                    { label = 'Grand Theft Auto', value = 'Grand Theft Auto' },
                    { label = 'Illegal Weapon Possession', value = 'Illegal Weapon Possession' },
                    { label = 'Public Intoxication', value = 'Public Intoxication' },
                    { label = 'Resisting Arrest', value = 'Resisting Arrest' },
                    { label = 'Robbery', value = 'Robbery' },
                    { label = 'Speeding', value = 'Speeding' },
                    { label = 'Vandalism', value = 'Vandalism' },
                    { label = 'Fleeing & Evading', value = 'Fleeing & Evading' },
                }

                local input = lib.inputDialog('Jail Player', {
                    { type = 'number', label = 'Player ID', description = 'ID of the player to jail', required = true, min = 1 },
                    { type = 'number', label = 'Time (Seconds)', description = 'Max Time: ' .. Config.MaxJailTime .. ' | Default: 30', default = 30, min = 1, max = Config.MaxJailTime },
                    { type = 'multi-select', label = 'Charges', description = 'Select charges (multiple allowed)', options = chargesOptions }
                })

                if not input then return end

                local id = input[1]
                local time = input[2]
                local selectedCharges = input[3]

                if not id or not time or not selectedCharges or #selectedCharges == 0 then
                    lib.notify({
                        title = 'Error',
                        description = 'Invalid input, please try again',
                        type = 'error',
                    })
                    return
                end

                local chargesText = ''
                for i, c in ipairs(selectedCharges) do
                    chargesText = chargesText .. c
                    if i < #selectedCharges then
                        chargesText = chargesText .. ', '
                    end
                end

                TriggerServerEvent('SEM_InteractionMenu:Jail', id, time, chargesText)
            end
        })

        if UnjailAllowed then
            table.insert(options, {
                title = 'Unjail',
                description = 'Unjail a player',
                onSelect = function()
                    local input = lib.inputDialog('Unjail Player', {
                        { type = 'number', label = 'Player ID', description = 'ID of the player to unjail', required = true, min = 1 }
                    })

                    if not input or not input[1] then
                        lib.notify({
                            title = 'Info',
                            description = 'Invalid input, please try again',
                            type = 'info',
                        })
                        return
                    end

                    TriggerServerEvent('SEM_InteractionMenu:Unjail', input[1])
                end
            })
        end
    end

    table.insert(options, {
        title = 'Deploy Spikes',
        description = 'Place spike strips on the ground',
        onSelect = function()
            local input = lib.inputDialog('Deploy Spikes', {
                { type = 'number', label = 'Number of strips (1-5)', default = 1, min = 1, max = 5 }
            })

            if not input or not input[1] then return end
            local count = tonumber(input[1]) or 1
            TriggerEvent('SEM_InteractionMenu:Spikes-SpawnSpikes', count)
        end
    })

    table.insert(options, {
        title = 'Remove Spikes',
        description = 'Remove spike strips placed on the ground',
        onSelect = function()
            TriggerEvent('SEM_InteractionMenu:Spikes-DeleteSpikes')
        end
    })

    table.insert(options, {
        title = 'Toggle Shield',
        description = 'Toggle the bulletproof shield',
        onSelect = function()
            if ShieldActive then
                DisableShield()
            else
                EnableShield()
            end
        end
    })

    if Config.UnrackWeapons == 1 or Config.UnrackWeapons == 2 then
        table.insert(options, {
            title = 'Toggle Carbine',
            description = 'Toggle your carbine rifle',
            onSelect = function()
                TriggerEvent('SEM_InteractionMenu:UnrackCarbine')
            end
        })

        table.insert(options, {
            title = 'Toggle Shotgun',
            description = 'Toggle your pump shotgun',
            onSelect = function()
                TriggerEvent('SEM_InteractionMenu:UnrackShotgun')
            end
        })
    end

    if Config.DisplayProps then
        table.insert(options, {
            title = 'Spawn Props',
            description = 'Spawn props on the ground',
            menu = 'sem_leo_props'
        })

        table.insert(options, {
            title = 'Remove Props',
            description = 'Remove the closest prop',
            onSelect = function()
                for _, prop in pairs(Config.Props) do
                    DeleteProp(prop.spawncode)
                end
            end
        })
    end

    lib.registerContext({
        id = 'sem_leo_actions',
        title = 'LEO Actions',
        options = options
    })
end

local function leoPropsContext()
    if not Config.DisplayProps then return end

    local options = {}

    for _, prop in pairs(Config.Props) do
        table.insert(options, {
            title = prop.name,
            description = 'Spawn prop: ' .. prop.name,
            onSelect = function()
                SpawnProp(prop.spawncode, prop.name)
            end
        })
    end

    lib.registerContext({
        id = 'sem_leo_props',
        title = 'LEO Props',
        options = options
    })
end

local function leoStationsContext()
    if not Config.ShowStations then return end

    local options = {}

    for _, station in pairs(Config.LEOStations) do
        table.insert(options, {
            title = station.name,
            description = 'Teleport to ' .. station.name,
            onSelect = function()
                teleportToCoords(station.coords)
            end
        })
    end

    lib.registerContext({
        id = 'sem_leo_stations',
        title = 'LEO Stations',
        options = options
    })
end

local function leoLoadoutsContext()
    if not (Config.DisplayLEOUniforms or Config.DisplayLEOLoadouts) then return end

    local options = {}

    if Config.DisplayLEOUniforms then
        table.insert(options, {
            title = 'Uniforms',
            menu = 'sem_leo_uniforms'
        })
    end

    if Config.DisplayLEOLoadouts then
        table.insert(options, {
            title = 'Loadouts',
            menu = 'sem_leo_weapon_loadouts'
        })
    end

    lib.registerContext({
        id = 'sem_leo_loadouts',
        title = 'LEO Loadouts',
        options = options
    })

    if Config.DisplayLEOUniforms then
        local uniformsOptions = {}

        for _, uniform in pairs(Config.LEOUniforms) do
            table.insert(uniformsOptions, {
                title = uniform.name,
                description = 'Spawn uniform: ' .. uniform.name,
                onSelect = function()
                    LoadPed(uniform.spawncode)
                    lib.notify({
                        title = 'Info',
                        description = 'Uniform spawned: ' .. uniform.name,
                        type = 'info',
                    })
                end
            })
        end

        lib.registerContext({
            id = 'sem_leo_uniforms',
            title = 'LEO Uniforms',
            options = uniformsOptions
        })
    end

    if Config.DisplayLEOLoadouts then
        local loadoutOptions = {}

        for name, loadout in pairs(Config.LEOLoadouts) do
            table.insert(loadoutOptions, {
                title = name,
                description = 'Equip loadout: ' .. name,
                onSelect = function()
                    SetEntityHealth(PlayerPedId(), 200)
                    RemoveAllPedWeapons(PlayerPedId(), true)
                    AddArmourToPed(PlayerPedId(), 100)

                    for _, weapon in pairs(loadout) do
                        GiveWeapon(weapon.weapon)

                        for _, component in pairs(weapon.components) do
                            if component ~= '' then
                                AddWeaponComponent(weapon.weapon, component)
                            end
                        end
                    end

                    lib.notify({
                        title = 'Info',
                        description = 'Loadout spawned: ' .. name,
                        type = 'info',
                    })
                end
            })
        end

        lib.registerContext({
            id = 'sem_leo_weapon_loadouts',
            title = 'LEO Weapon Loadouts',
            options = loadoutOptions
        })
    end
end

local function leoVehiclesContext()
    if not Config.ShowLEOVehicles then return end

    local categoryOptions = {}

    for name, category in pairs(Config.LEOVehiclesCategories) do
        local contextId = 'sem_leo_vehicles_' .. name

        table.insert(categoryOptions, {
            title = name,
            menu = contextId
        })

        local vehiclesOptions = {}

        for _, veh in pairs(category) do
            table.insert(vehiclesOptions, {
                title = veh.name,
                description = Config.ShowLEOSpawnCode and veh.spawncode or nil,
                onSelect = function()
                    SpawnVehicle(veh.spawncode, veh.name, veh.livery, veh.extras)
                end
            })
        end

        lib.registerContext({
            id = contextId,
            title = 'LEO Vehicles - ' .. name,
            options = vehiclesOptions
        })
    end

    lib.registerContext({
        id = 'sem_leo_vehicles',
        title = 'LEO Vehicles',
        options = categoryOptions
    })
end

local function leoTrafficContext()
    if not Config.DisplayTrafficManager then return end

    lib.registerContext({
        id = 'sem_leo_traffic',
        title = 'Traffic Manager',
        options = {
            {
                title = 'Set Radius',
                description = 'Current: ' .. TMSize .. 'm',
                onSelect = function()
                    local input = lib.inputDialog('Set Radius', {
                        { type = 'number', label = 'Radius (meters)', default = TMSize, min = 5, max = 200 }
                    })

                    if input and input[1] then
                        TMSize = tonumber(input[1]) or TMSize
                    end
                end
            },
            {
                title = 'Set Speed',
                description = 'Current: ' .. TMSpeed .. ' mph',
                onSelect = function()
                    local input = lib.inputDialog('Set Speed', {
                        { type = 'number', label = 'Speed (mph)', default = TMSpeed, min = 0, max = 120 }
                    })

                    if input and input[1] then
                        TMSpeed = tonumber(input[1]) or TMSpeed
                    end
                end
            },
            {
                title = 'Create Speed Zone',
                description = 'Create a speed zone at your location',
                onSelect = createSpeedZone
            },
            {
                title = 'Delete Speed Zone',
                description = 'Delete your active speed zone',
                onSelect = deleteSpeedZone
            }
        }
    })
end

--============================--
--        FIRE MENUS          --
--============================--

local function fireActionsContext()
    local options = {}

    table.insert(options, {
        title = 'Drag',
        description = 'Drag/Undrag the closest player',
        onSelect = function()
            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:DragNear', player)
            end
        end
    })

    table.insert(options, {
        title = 'Seat',
        description = 'Place a player in the closest vehicle',
        onSelect = function()
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, true)
            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:SeatNear', player, veh)
            end
        end
    })

    table.insert(options, {
        title = 'Unseat',
        description = 'Remove a player from the closest vehicle',
        onSelect = function()
            if IsPedInAnyVehicle(PlayerPedId(), true) then
                lib.notify({
                    title = 'Info',
                    description = 'You need to be outside of the vehicle',
                    type = 'info',
                })
                return
            end

            local player = GetClosestPlayer()
            if player ~= false then
                TriggerServerEvent('SEM_InteractionMenu:UnseatNear', player)
            end
        end
    })

    if Config.FireHospital then
        for hospitalName, hospitalInfo in pairs(Config.HospitalLocation) do
            table.insert(options, {
                title = 'Hospitalize - ' .. hospitalName,
                description = 'Hospitalize a player at ' .. hospitalName,
                onSelect = function()
                    local input = lib.inputDialog('Hospitalize Player', {
                        { type = 'number', label = 'Player ID', description = 'Enter the player ID', required = true, min = 1 },
                        { type = 'number', label = 'Time (Seconds)', description = 'Enter hospitalization time (Max: ' .. Config.MaxHospitalTime .. ' | Default: 30)', required = true, min = 1, max = Config.MaxHospitalTime, default = 30 }
                    })

                    if not input then return end

                    local playerId = input[1]
                    local time = input[2]

                    if not playerId or not time then
                        lib.notify({
                            title = 'Error',
                            description = 'Invalid input, please try again',
                            type = 'error',
                        })
                        return
                    end

                    if time > Config.MaxHospitalTime then
                        lib.notify({
                            title = 'Info',
                            description = 'Exceeded max time | Max Time: ' .. Config.MaxHospitalTime .. ' seconds',
                            type = 'info',
                        })
                        time = Config.MaxHospitalTime
                    end

                    lib.notify({
                        title = 'Info',
                        description = 'Player hospitalized for ' .. time .. ' seconds',
                        type = 'info',
                    })

                    TriggerServerEvent('SEM_InteractionMenu:Hospitalize', playerId, time, hospitalInfo)
                end
            })
        end

        if UnhospitalAllowed then
            table.insert(options, {
                title = 'Unhospitalize',
                description = 'Unhospitalize a player',
                onSelect = function()
                    local input = lib.inputDialog('Unhospitalize Player', {
                        { type = 'number', label = 'Player ID', description = 'Enter the player ID to unhospitalize', required = true, min = 1 }
                    })

                    if not input or not input[1] then
                        lib.notify({
                            title = 'Info',
                            description = 'Invalid input, please try again',
                            type = 'info',
                        })
                        return
                    end

                    TriggerServerEvent('SEM_InteractionMenu:Unhospitalize', input[1])
                end
            })
        end
    end

    if Config.DisplayProps then
        table.insert(options, {
            title = 'Spawn Props',
            description = 'Spawn props on the ground',
            menu = 'sem_fire_props'
        })

        table.insert(options, {
            title = 'Remove Props',
            description = 'Remove the closest prop',
            onSelect = function()
                for _, prop in pairs(Config.Props) do
                    DeleteProp(prop.spawncode)
                end
            end
        })
    end

    lib.registerContext({
        id = 'sem_fire_actions',
        title = 'Fire Actions',
        options = options
    })
end

local function firePropsContext()
    if not Config.DisplayProps then return end

    local options = {}

    for _, prop in pairs(Config.Props) do
        table.insert(options, {
            title = prop.name,
            description = 'Spawn prop: ' .. prop.name,
            onSelect = function()
                SpawnProp(prop.spawncode, prop.name)
            end
        })
    end

    lib.registerContext({
        id = 'sem_fire_props',
        title = 'Fire Props',
        options = options
    })
end

local function fireStationsContext()
    if not Config.ShowStations then return end

    local fireOptions = {}
    for _, station in pairs(Config.FireStations) do
        table.insert(fireOptions, {
            title = station.name,
            description = 'Teleport to fire station ' .. station.name,
            onSelect = function()
                teleportToCoords(station.coords)
            end
        })
    end

    local hospitalOptions = {}
    for _, station in pairs(Config.HospitalStations) do
        table.insert(hospitalOptions, {
            title = station.name,
            description = 'Teleport to hospital ' .. station.name,
            onSelect = function()
                teleportToCoords(station.coords)
            end
        })
    end

    lib.registerContext({
        id = 'sem_fire_stations_fire',
        title = 'Fire Stations',
        options = fireOptions
    })

    lib.registerContext({
        id = 'sem_fire_stations_hospital',
        title = 'Hospital Stations',
        options = hospitalOptions
    })

    lib.registerContext({
        id = 'sem_fire_stations',
        title = 'Stations',
        options = {
            { title = 'Fire Stations', menu = 'sem_fire_stations_fire' },
            { title = 'Hospitals', menu = 'sem_fire_stations_hospital' },
        }
    })
end

local function fireLoadoutsContext()
    if not (Config.DisplayFireUniforms or Config.DisplayFireLoadouts) then return end

    local options = {}

    if Config.DisplayFireUniforms then
        table.insert(options, { title = 'Uniforms', menu = 'sem_fire_uniforms' })
    end

    if Config.DisplayFireLoadouts then
        table.insert(options, { title = 'Loadouts', menu = 'sem_fire_weapon_loadouts' })
    end

    lib.registerContext({
        id = 'sem_fire_loadouts',
        title = 'Fire Loadouts',
        options = options
    })

    if Config.DisplayFireUniforms then
        local uniformsOptions = {}
        for _, uniform in pairs(Config.FireUniforms) do
            table.insert(uniformsOptions, {
                title = uniform.name,
                description = 'Spawn uniform: ' .. uniform.name,
                onSelect = function()
                    LoadPed(uniform.spawncode)
                    lib.notify({
                        title = 'Info',
                        description = 'Uniform spawned: ' .. uniform.name,
                        type = 'info',
                    })
                end
            })
        end

        lib.registerContext({
            id = 'sem_fire_uniforms',
            title = 'Fire Uniforms',
            options = uniformsOptions
        })
    end

    if Config.DisplayFireLoadouts then
        local loadoutOptions = {}

        for name, loadout in pairs(Config.FireLoadouts) do
            table.insert(loadoutOptions, {
                title = name,
                description = 'Equip loadout: ' .. name,
                onSelect = function()
                    SetEntityHealth(PlayerPedId(), 200)
                    RemoveAllPedWeapons(PlayerPedId(), true)
                    AddArmourToPed(PlayerPedId(), 100)

                    for _, weapon in pairs(loadout) do
                        GiveWeapon(weapon.weapon)
                        for _, component in pairs(weapon.components) do
                            if component ~= '' then
                                AddWeaponComponent(weapon.weapon, component)
                            end
                        end
                    end

                    lib.notify({
                        title = 'Info',
                        description = 'Loadout spawned: ' .. name,
                        type = 'info',
                    })
                end
            })
        end

        lib.registerContext({
            id = 'sem_fire_weapon_loadouts',
            title = 'Fire Weapon Loadouts',
            options = loadoutOptions
        })
    end
end

local function fireVehiclesContext()
    if not Config.ShowFireVehicles then return end

    local options = {}

    for _, veh in pairs(Config.FireVehicles) do
        table.insert(options, {
            title = veh.name,
            description = Config.ShowFireSpawnCode and veh.spawncode or nil,
            onSelect = function()
                SpawnVehicle(veh.spawncode, veh.name, veh.livery, veh.extras)
            end
        })
    end

    lib.registerContext({
        id = 'sem_fire_vehicles',
        title = 'Fire Vehicles',
        options = options
    })
end

--============================--
--        CIV MENUS           --
--============================--

local function civContext()
    if not CivRestrict() then return end

    local options = {
        { title = 'Actions', menu = 'sem_civ_actions' }
    }

    if Config.ShowCivAdverts then
        table.insert(options, { title = 'Adverts', menu = 'sem_civ_adverts' })
    end

    if Config.ShowCivVehicles then
        table.insert(options, { title = 'Vehicles', menu = 'sem_civ_vehicles' })
    end

    lib.registerContext({
        id = 'sem_civ',
        title = 'Civ Toolbox',
        options = options
    })

    -- actions
    local actionOptions = {}

    table.insert(actionOptions, {
        title = 'Inventory',
        description = 'Set your inventory',
        onSelect = function()
            local input = lib.inputDialog('Set Your Inventory', {
                { type = 'input', label = 'Items', description = 'Enter your inventory items (max 75 characters)', required = true, max = 75 }
            })

            if input and input[1] and input[1] ~= '' then
                TriggerServerEvent('SEM_InteractionMenu:InventorySet', input[1])
                lib.notify({
                    title = 'Inventory Set',
                    type = 'success',
                })
            else
                lib.notify({
                    title = 'Info',
                    description = 'No items provided',
                    type = 'info',
                })
            end
        end
    })

    table.insert(actionOptions, {
        title = 'BAC',
        description = 'Set your BAC level',
        onSelect = function()
            local input = lib.inputDialog('Set Your BAC', {
                { type = 'input', label = 'BAC Level', description = 'Enter your BAC level (0.00 to 0.40)', required = true }
            })

            if not input or not input[1] then
                lib.notify({
                    title = 'Info',
                    description = 'BAC setting canceled',
                    type = 'info',
                })
                return
            end

            local bacLevel = tonumber(input[1])
            if bacLevel and bacLevel >= 0.0 and bacLevel <= 0.40 then
                TriggerServerEvent('SEM_InteractionMenu:BACSet', bacLevel)
                lib.notify({
                    title = 'BAC Level Set',
                    description = string.format('Your BAC level has been set to: %.2f', bacLevel),
                    type = 'success',
                })
            else
                lib.notify({
                    title = 'Error',
                    description = 'Invalid BAC level entered. Please enter a number between 0.00 and 0.40.',
                    type = 'error',
                })
            end
        end
    })

    table.insert(actionOptions, {
        title = 'Drop Weapon',
        description = 'Drop your current weapon on the ground',
        onSelect = function()
            local currentWeapon = GetSelectedPedWeapon(PlayerPedId())
            SetCurrentPedWeapon(PlayerPedId(), `weapon_unarmed`, true)
            SetPedDropsInventoryWeapon(PlayerPedId(), currentWeapon, -2.0, 0.0, 0.5, 30)
            lib.notify({
                title = 'Weapon Dropped',
                type = 'success',
            })
        end
    })

    lib.registerContext({
        id = 'sem_civ_actions',
        title = 'Civilian Actions',
        options = actionOptions
    })

    -- adverts
    if Config.ShowCivAdverts then
        local advertsOptions = {}

        for _, ad in pairs(Config.CivAdverts) do
            table.insert(advertsOptions, {
                title = ad.name,
                description = 'Send an advert for ' .. ad.name,
                onSelect = function()
                    local input = lib.inputDialog('Send Advert: ' .. ad.name, {
                        { type = 'input', label = 'Message', description = 'Enter your advert message', required = true, max = 128 }
                    })

                    if not input or not input[1] or input[1] == '' then
                        lib.notify({
                            title = 'Info',
                            description = 'No advert message provided',
                            type = 'info',
                        })
                        return
                    end

                    TriggerServerEvent('SEM_InteractionMenu:Ads', input[1], ad.name, ad.loc, ad.file)
                end
            })
        end

        lib.registerContext({
            id = 'sem_civ_adverts',
            title = 'Civilian Adverts',
            options = advertsOptions
        })
    end

    -- civ vehicles
    if Config.ShowCivVehicles then
        local vehiclesOptions = {}

        for _, veh in pairs(Config.CivVehicles) do
            table.insert(vehiclesOptions, {
                title = veh.name,
                description = Config.ShowCivSpawnCode and veh.spawncode or nil,
                onSelect = function()
                    SpawnVehicle(veh.spawncode, veh.name)
                end
            })
        end

        lib.registerContext({
            id = 'sem_civ_vehicles',
            title = 'Civilian Vehicles',
            options = vehiclesOptions
        })
    end
end

--============================--
--       VEHICLE MENU         --
--============================--

local function vehicleContext()
    if not VehicleRestrict() then return end

    local options = {
        {
            title = 'Toggle Engine',
            description = 'Toggle your vehicle engine',
            onSelect = toggleVehicleEngine
        },
        {
            title = 'Toggle Interior Light',
            description = 'Toggle your vehicle interior light',
            onSelect = toggleInteriorLight
        },
        {
            title = 'Change Seats',
            description = 'Switch to a different seat',
            onSelect = changeSeat
        },
        {
            title = 'Windows',
            description = 'Open/Close your vehicle windows',
            menu = 'sem_vehicle_windows'
        },
        {
            title = 'Doors',
            description = 'Open/Close your vehicle doors',
            menu = 'sem_vehicle_doors'
        },
    }

    if Config.VehicleOptions then
        table.insert(options, {
            title = 'Repair Vehicle',
            description = 'Repair your current vehicle',
            onSelect = repairVehicle
        })

        table.insert(options, {
            title = 'Clean Vehicle',
            description = 'Clean your current vehicle',
            onSelect = cleanVehicle
        })

        table.insert(options, {
            title = 'Delete Vehicle',
            description = 'Delete your current vehicle',
            onSelect = deleteVehicle
        })
    end

    lib.registerContext({
        id = 'sem_vehicle',
        title = 'Vehicle',
        description = 'Vehicle related options',
        options = options
    })

    lib.registerContext({
        id = 'sem_vehicle_windows',
        title = 'Vehicle Windows',
        options = {
            {
                title = 'Front',
                description = 'Toggle front windows',
                onSelect = function() handleWindows('front') end
            },
            {
                title = 'Rear',
                description = 'Toggle rear windows',
                onSelect = function() handleWindows('rear') end
            },
            {
                title = 'All',
                description = 'Toggle all windows',
                onSelect = function() handleWindows('all') end
            },
        }
    })

    lib.registerContext({
        id = 'sem_vehicle_doors',
        title = 'Vehicle Doors',
        options = {
            {
                title = 'Driver',
                description = 'Toggle driver door',
                onSelect = function() handleDoors('driver') end
            },
            {
                title = 'Passenger',
                description = 'Toggle passenger door',
                onSelect = function() handleDoors('passenger') end
            },
            {
                title = 'Rear Right',
                description = 'Toggle rear right door',
                onSelect = function() handleDoors('rear_right') end
            },
            {
                title = 'Rear Left',
                description = 'Toggle rear left door',
                onSelect = function() handleDoors('rear_left') end
            },
            {
                title = 'Hood',
                description = 'Toggle hood',
                onSelect = function() handleDoors('hood') end
            },
            {
                title = 'Trunk',
                description = 'Toggle trunk',
                onSelect = function() handleDoors('trunk') end
            },
            {
                title = 'All',
                description = 'Toggle all doors',
                onSelect = function() handleDoors('all') end
            },
        }
    })
end

--============================--
--        EMOTES MENU         --
--============================--

local function emotesContext()
    if not EmoteRestrict() then return end

    local options = {}

    for _, emote in pairs(Config.EmotesList) do
        table.insert(options, {
            title = emote.name,
            description = 'Play emote',
            onSelect = function()
                PlayEmote(emote.emote, emote.name)
            end
        })
    end

    table.insert(options, {
        title = 'Cancel Emote',
        description = 'Stop current emote',
        onSelect = function()
            CancelEmote()
        end
    })

    lib.registerContext({
        id = 'sem_emotes',
        title = 'Emotes',
        description = 'General RP emotes',
        options = options
    })
end

--============================--
--        MAIN MENU           --
--============================--

local function openInteractionMenu()
    local mainOptions = {}

    if LEORestrict() then
        table.insert(mainOptions, { title = 'LEO Toolbox', description = 'Law Enforcement related menu', menu = 'sem_leo' })
    end

    if FireRestrict() then
        table.insert(mainOptions, { title = 'Fire Toolbox', description = 'Fire related menu', menu = 'sem_fire' })
    end

    if CivRestrict() then
        table.insert(mainOptions, { title = 'Civ Toolbox', description = 'Civilian related menu', menu = 'sem_civ' })
    end

    if VehicleRestrict() then
        table.insert(mainOptions, { title = 'Vehicle', description = 'Vehicle related menu', menu = 'sem_vehicle' })
    end

    if EmoteRestrict() then
        table.insert(mainOptions, { title = 'Emotes', description = 'General RP emotes', menu = 'sem_emotes' })
    end

    if #mainOptions == 0 then
        lib.notify({
            title = 'Info',
            description = 'You do not have access to any menu sections',
            type = 'info',
        })
        return
    end

    -- build sub contexts
    if LEORestrict() then
        leoActionsContext()
        leoPropsContext()
        leoStationsContext()
        leoLoadoutsContext()
        leoVehiclesContext()
        leoTrafficContext()

        local leoOptions = {
            { title = 'Actions', menu = 'sem_leo_actions' },
        }

        if Config.ShowStations then
            table.insert(leoOptions, { title = 'Stations', menu = 'sem_leo_stations' })
        end

        if Config.DisplayLEOUniforms or Config.DisplayLEOLoadouts then
            table.insert(leoOptions, { title = 'Loadouts', menu = 'sem_leo_loadouts' })
        end

        if Config.ShowLEOVehicles then
            table.insert(leoOptions, { title = 'Vehicles', menu = 'sem_leo_vehicles' })
        end

        if Config.DisplayTrafficManager then
            table.insert(leoOptions, { title = 'Traffic Manager', menu = 'sem_leo_traffic' })
        end

        lib.registerContext({
            id = 'sem_leo',
            title = 'LEO Toolbox',
            options = leoOptions
        })
    end

    if FireRestrict() then
        fireActionsContext()
        firePropsContext()
        fireStationsContext()
        fireLoadoutsContext()
        fireVehiclesContext()

        local fireOptions = {
            { title = 'Actions', menu = 'sem_fire_actions' },
        }

        if Config.ShowStations then
            table.insert(fireOptions, { title = 'Stations', menu = 'sem_fire_stations' })
        end

        if Config.DisplayFireUniforms or Config.DisplayFireLoadouts then
            table.insert(fireOptions, { title = 'Loadouts', menu = 'sem_fire_loadouts' })
        end

        if Config.ShowFireVehicles then
            table.insert(fireOptions, { title = 'Vehicles', menu = 'sem_fire_vehicles' })
        end

        lib.registerContext({
            id = 'sem_fire',
            title = 'Fire Toolbox',
            options = fireOptions
        })
    end

    civContext()
    vehicleContext()
    emotesContext()

    lib.registerContext({
        id = 'sem_main',
        title = getMenuTitle(),
        description = getMenuSubtitle(),
        options = mainOptions
    })

    lib.showContext('sem_main')
end

-- Key / command handling (replacing NativeUI keybind logic)
CreateThread(function()
    if Config.OpenMenu ~= 0 then return end

    while true do
        Wait(0)
        if IsControlJustPressed(1, Config.MenuButton) and GetLastInputMethod(2) then
            openInteractionMenu()
        end
    end
end)

RegisterCommand(Config.Command, function()
    if Config.OpenMenu == 1 then
        openInteractionMenu()
    end
end, false)

CreateThread(function()
    if Config.OpenMenu == 1 then
        TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Used to open SEM_InteractionMenu')
    end
end)
