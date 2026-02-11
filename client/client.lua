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


-- Texto arriba
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        for _, ped in ipairs(GetGamePool("CPed")) do
            if DoesEntityExist(ped) then
                local state = Entity(ped).state
                local speech = state.lastSpeech

                if speech and speech ~= "" then
                    local coords = GetEntityCoords(ped)
                    DrawText3D(coords.x, coords.y, coords.z + 1.0, speech)
                end
            end
        end
    end
end)


-- Functions

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)

    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 100)
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
