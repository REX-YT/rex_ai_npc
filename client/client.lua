local humanPeds       = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/human-peds.json'))

local targeting       = false
local targetedPed     = nil
local lastTargetedPed = nil

local textUIOpen = false
local uiBusy = false

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

                ClearPedTasks(targetedPed)
                TaskTurnPedToFaceEntity(targetedPed, PlayerPedId(), 1000)
                FreezeEntityPosition(targetedPed, true)

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


-- Texto arriba con animacion
Citizen.CreateThread(function()
    RequestAnimDict("facials@gen_male@variations@normal")
    while not HasAnimDictLoaded("facials@gen_male@variations@normal") do
        Citizen.Wait(0)
    end

    while true do
        Citizen.Wait(0)

        for _, ped in ipairs(GetGamePool("CPed")) do
            if DoesEntityExist(ped) then
                local state = Entity(ped).state
                local speech = state.lastSpeech
                local netId = NetworkGetNetworkIdFromEntity(ped)
                local soundName = "ped_tts_" .. netId

                if state.isSpeaking then

                    -- Animación
                    if not IsEntityPlayingAnim(ped, "facials@gen_male@variations@normal", "talk_01", 3) then
                        TaskPlayAnim(ped,
                            "facials@gen_male@variations@normal",
                            "talk_01",
                            8.0, -8.0, -1, 49, 0, false, false, false
                        )
                    end

                    -- Texto
                    if speech and speech ~= "" then
                        local coords = GetEntityCoords(ped)
                        DrawText3D(coords.x, coords.y, coords.z + 1.0, speech)
                    end

                    -- ACTUALIZAR POSICIÓN DEL SONIDO
                    if exports.xsound:soundExists(soundName) then
                        local coords = GetEntityCoords(ped)
                        exports.xsound:Position(soundName, coords)
                    end

                else
                    ClearPedSecondaryTask(ped)
                end
            end
        end
    end
end)


-- Functions

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoords()
    local dist = #(vector3(x,y,z) - camCoords)

    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    SetTextScale(0.0 * scale, 0.45 * scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextEntry("STRING")

    -- Wrap automático
    SetTextWrap(0.0, 1.0)

    AddTextComponentString(text)
    DrawText(_x, _y)

    local factor = string.len(text) / 400
    DrawRect(_x, _y + 0.0125, 0.02 + factor, 0.035 + (factor * 0.5), 0, 0, 0, 120)
end



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
            "ai_ped:talk",
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
