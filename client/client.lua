local humanPeds       = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/human-peds.json'))

local targeting       = false
local targetedPed     = nil
local lastTargetedPed = nil

local textUIOpen = false
local uiBusy = false

local activeTalkingPeds = {}

-- Threads

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)

    local playerId = PlayerPedId()
    local playerCoordinates = GetEntityCoords(playerId)
    local streetHash, crossStreetHash = GetStreetNameAtCoord(table.unpack(playerCoordinates))
    local streetName = GetStreetNameFromHashKey(streetHash)
    local crossStreetName = GetStreetNameFromHashKey(crossStreetHash)

    LocalPlayer.state:set('curStreetName', streetName, true)
    LocalPlayer.state:set('curCrossStreetName', crossStreetName, true)
  end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local hit, entityHit, endCoords = raycastFromCamera(8)

        targetedPed = nil

        if hit == 1 
            and DoesEntityExist(entityHit) 
            and IsEntityAPed(entityHit) 
            and not IsPedAPlayer(entityHit) 
            and not IsPedDeadOrDying(entityHit, true) then

            local distance = #(playerCoords - endCoords)
            local pedModel = tostring(GetEntityModel(entityHit))

            if distance < 3.0 and humanPeds[pedModel] then
                targetedPed = entityHit
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- Si estamos mirando un ped válido
        if targetedPed then

            -- Cambiamos de ped
            if lastTargetedPed and lastTargetedPed ~= targetedPed then
                handleDetarget()
            end

            -- Primer targeting
            if not lastTargetedPed then
                lastTargetedPed = targetedPed

ClearPedTasksImmediately(targetedPed)

SetEntityAsMissionEntity(targetedPed, true, true)
SetBlockingOfNonTemporaryEvents(targetedPed, true)
FreezeEntityPosition(targetedPed, true)

TaskTurnPedToFaceEntity(targetedPed, PlayerPedId(), -1)
TaskLookAtEntity(targetedPed, PlayerPedId(), -1, 2048, 3)



                if not textUIOpen then
                    textUIOpen = true
                    lib.showTextUI('[L] - Hablar', {
                        position = 'right-center',
                        icon = 'comments',
                        iconColor = '#00ff88'
                    })
                end
            end

            -- Pulsar L
            if IsControlJustPressed(0, 182) and not uiBusy then
                uiBusy = true
                openInputDialog()
            end

        else
            -- No estamos mirando nada válido
            if lastTargetedPed then
                handleDetarget()
            end
        end
    end
end)

-- Detectar cambios de estado sincronizado
AddStateBagChangeHandler('isSpeaking', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 then return end

    local netId = NetworkGetNetworkIdFromEntity(entity)

    if value then
        activeTalkingPeds[entity] = true
    else
        activeTalkingPeds[entity] = nil
        ClearPedTasks(entity)
        ClearPedSecondaryTask(entity)

        SendNUIMessage({
            type = "removeSpeech",
            netId = netId
        })
    end
end)


-- Cargar anim dict correctamente
Citizen.CreateThread(function()
    RequestAnimDict("facials@gen_male@variations@normal")
    while not HasAnimDictLoaded("facials@gen_male@variations@normal") do
        Citizen.Wait(100)
    end
end)

-- LOOP ULTRA LIVIANO
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        for ped,_ in pairs(activeTalkingPeds) do
            if DoesEntityExist(ped) then

                local state = Entity(ped).state
                local coords = GetEntityCoords(ped)
                local playerPed = PlayerPedId()

                -- HACER QUE MIRE AL JUGADOR SIEMPRE
                TaskLookAtEntity(ped, playerPed, 1000, 2048, 3)

                -- ANIMACIÓN FACIAL REAL
                if not IsEntityPlayingAnim(ped, "facials@gen_male@variations@normal", "talk_01", 3) then
                    TaskPlayAnim(
                        ped,
                        "facials@gen_male@variations@normal",
                        "talk_01",
                        8.0, -8.0,
                        -1,
                        49,
                        0,
                        false, false, false
                    )
                end

                -- TEXTO 3D
local netId = NetworkGetNetworkIdFromEntity(ped)

if state.lastSpeech and state.lastSpeech ~= "" then

    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)

    if onScreen then
        SendNUIMessage({
            type = "updateSpeech",
            netId = netId,
            text = state.lastSpeech,
            x = screenX,
            y = screenY,
            visible = true
        })
    else
        SendNUIMessage({
            type = "updateSpeech",
            netId = netId,
            visible = false
        })
    end
                        end

                -- ACTUALIZAR POSICIÓN DEL SONIDO
if netId and netId ~= 0 then
    local soundName = "ped_tts_" .. netId

    if exports.xsound and exports.xsound:soundExists(soundName) then
        local success = pcall(function()
            exports.xsound:Position(soundName, coords)
        end)

        if not success then
            -- opcional: limpiar ped roto
            activeTalkingPeds[ped] = nil
        end
    end
end


            else
                activeTalkingPeds[ped] = nil
            end
        end
    end
end)



-- Functions

function openInputDialog()
    local input = lib.inputDialog('Hablar con el ciudadano', {
        {
            type = 'textarea',
            label = 'Mensaje',
            placeholder = 'Escribe lo que quieres decir...',
            required = true,
            min = 3,
            max = 200,
            autosize = true
        }
    })

    if input and lastTargetedPed then
        TriggerServerEvent(
            "rex_ia_npc:talk",
            NetworkGetNetworkIdFromEntity(lastTargetedPed),
            tostring(GetEntityModel(lastTargetedPed)),
            input[1]
        )
    end

    uiBusy = false
end


function handleDetarget()
    if DoesEntityExist(lastTargetedPed) then
        FreezeEntityPosition(lastTargetedPed, false)
        SetBlockingOfNonTemporaryEvents(lastTargetedPed, false)
        ClearPedTasksImmediately(lastTargetedPed)
        TaskWanderStandard(lastTargetedPed, 10.0, 10)
    end

    if textUIOpen then
        textUIOpen = false
        lib.hideTextUI()
    end

    lastTargetedPed = nil
end


function raycastFromCamera(flag)
  local coords, normal = GetWorldCoordFromScreenCoord(0.5, 0.5)
  local destination    = coords + normal * 10

  local handle         = StartShapeTestLosProbe(
    coords.x,
    coords.y,
    coords.z,
    destination.x,
    destination.y,
    destination.z,
    flag,
    PlayerPedId(),
    4
  )

  while true do
    Citizen.Wait(0)

    local retVal, hit, endCoords, surfaceNormal, materialHash, entityHit = GetShapeTestResultIncludingMaterial(handle)

    if retVal ~= 1 then
      return hit, entityHit, endCoords, surfaceNormal, materialHash
    end
  end
end
