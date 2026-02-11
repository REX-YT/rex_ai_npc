local humanPeds       = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/human-peds.json'))

local targeting       = false
local targetedPed     = nil
local lastTargetedPed = nil

local textUIOpen = false
local uiBusy = false
local currentPed = nil

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

    if hit == 1 then
      local distance = #(playerCoords - endCoords)
      local pedModel = tostring(GetEntityModel(entityHit))

      if distance < 3.0 and humanPeds[pedModel] then

        -- Mostrar TextUI solo una vez
        if not textUIOpen then
          textUIOpen = true
          lib.showTextUI('[L] - Hablar', {
            position = 'right-center',
            icon = 'comments',
            iconColor = '#00ff88'
          })
        end

        -- Presiona L para hablar
if IsControlJustPressed(0, 182) and not uiBusy then
    uiBusy = true
    currentPed = entityHit

    ClearPedTasksImmediately(currentPed)
    TaskTurnPedToFaceEntity(currentPed, PlayerPedId(), 1000)
    FreezeEntityPosition(currentPed, true)

    openInputDialog()
end


      else
        if textUIOpen then
          textUIOpen = false
          lib.hideTextUI()
        end
      end
    else
      if textUIOpen then
        textUIOpen = false
        lib.hideTextUI()
      end
    end
  end
end)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)

    if not targeting then
      if lastTargetedPed then
        handleDetarget()
      end

      goto continue
    end

    if targeting then
      if lastTargetedPed and lastTargetedPed ~= targetedPed then
        handleDetarget()
      end

      if not lastTargetedPed then
        lastTargetedPed = targetedPed

        LocalPlayer.state:set('targetedPed', NetworkGetNetworkIdFromEntity(targetedPed), true)

        ClearPedTasksImmediately(targetedPed)

        TaskTurnPedToFaceEntity(targetedPed, PlayerPedId(), 1000)

        Citizen.Wait(1000)

        FreezeEntityPosition(targetedPed, true)
      end

      TaskStandStill(targetedPed, 1000)
    end

    ::continue::
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
      max = 6,
      autosize = true
    }
  })

  if not input then
      if currentPed then
          FreezeEntityPosition(currentPed, false)
      end
      uiBusy = false
      return
  end

  if currentPed then
    TriggerServerEvent(
      "ai_ped:talk",
      NetworkGetNetworkIdFromEntity(currentPed),
      tostring(GetEntityModel(currentPed)),
      input[1]
    )

    FreezeEntityPosition(currentPed, false)
  end

  uiBusy = false
end



function handleDetarget()
  if DoesEntityExist(lastTargetedPed) then
    FreezeEntityPosition(lastTargetedPed, false)
    TaskWanderStandard(lastTargetedPed, 10.0, 10)
  end

  LocalPlayer.state:set('targetedPed', nil, true)

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
