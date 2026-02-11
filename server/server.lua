local humanPeds = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/human-peds.json'))
local conversations = {}

-- Functions

function generateResponse(playerId, pedId, pedModel, message)
  table.insert(conversations[playerId][pedId], {
    role    = 'user',
    content = message
  })

  PerformHttpRequest('https://api.openai.com/v1/chat/completions', function(code, data, headers)
    if code ~= 200 then
      Entity(NetworkGetEntityFromNetworkId(pedId)).state:set('isThinking', false, true)
    end

    local _data = json.decode(data)
    local response = _data.choices[1].message.content

    table.insert(conversations[playerId][pedId], {
      role = 'assistant',
      content = response
    })
            
            local entity = NetworkGetEntityFromNetworkId(pedId)
if entity and entity ~= 0 then
    Entity(entity).state:set('lastSpeech', response, true)
end

    local ttsUrl = nil

    PerformHttpRequest('https://api.v8.unrealspeech.com/synthesisTasks', function(code, data, headers)   

       if code ~= 200 or not data then
        Entity(NetworkGetEntityFromNetworkId(pedId)).state:set('isThinking', false, true)
        return
    end

    local __data = json.decode(data)

    if not __data or not __data.SynthesisTask or not __data.SynthesisTask.OutputUri then
        print("TTS INVALID JSON:", data)
        Entity(NetworkGetEntityFromNetworkId(pedId)).state:set('isThinking', false, true)
        return
    end
                    
      ttsUrl = __data.SynthesisTask.OutputUri
    end, 'POST', json.encode({
      Text = response,
      VoiceId = Config.Voices[humanPeds[pedModel].gender],
      Bitrate = "192k",
      Speed = "0",
      Pitch = "1",
      TimestampType = "sentence",
    }), {
      ['Content-Type'] = 'application/json',
      ['Authorization'] = ('Bearer %s'):format(Config.TTSAPIKey),
    })


    if not ttsUrl then
      Entity(NetworkGetEntityFromNetworkId(pedId)).state:set('isThinking', false, true)
    end

    local soundReady = false

    while not soundReady do
      PerformHttpRequest(ttsUrl, function(code)
        if code == 200 then
          soundReady = true
        end
      end, 'GET', nil, {})
      Citizen.Wait(1)
    end

    local soundId = exports.sounity:CreateSound(ttsUrl)

    exports.sounity:AttachSound(soundId, pedId)
    exports.sounity:StartSound(soundId)

    Entity(NetworkGetEntityFromNetworkId(pedId)).state:set('isThinking', false, true)
    Entity(NetworkGetEntityFromNetworkId(pedId)).state:set('isSpeaking', true, true)

Citizen.SetTimeout(5000, function()
    local entity = NetworkGetEntityFromNetworkId(pedId)
    if entity and entity ~= 0 then
        Entity(entity).state:set('isSpeaking', false, true)
        Entity(entity).state:set('lastSpeech', nil, true)
    end
end)

  end, 'POST', json.encode({
    model = Config.ChatGPTModel,
    messages = conversations[playerId][pedId],
  }), {
    ['Content-Type'] = 'application/json',
    ['Authorization'] = ('Bearer %s'):format(Config.APIKey),
  })
end

function setupConversation(playerId, pedId, pedModel)
    local pedData     = humanPeds[pedModel]
    local playerState = Player(playerId).state
    local easyData    = exports['cd_easytime']:GetAllData()
    local systemPrompt = Config.SystemPrompt

    -- Seguridad por si algo viene nil
    local hour    = easyData and easyData.hours or 0
    local minute  = easyData and easyData.mins or 0
    local weather = easyData and easyData.weather or "UNKNOWN"

    local variables = {
        GENDER       = pedData.gender,
        PERSONALITY  = pedData.personality,
        TIME_HOUR    = string.format("%02d", hour),
        TIME_MINUTE  = string.format("%02d", minute),
        WEATHER      = weather,
        STREET       = playerState.curStreetName or 'Unknown',
        CROSS_STREET = playerState.curCrossStreetName or 'Unknown'
    }

    for k, v in pairs(variables) do
        systemPrompt = systemPrompt:gsub(('{%s}'):format(k), tostring(v))
    end

    conversations[playerId] = conversations[playerId] or {}
    conversations[playerId][pedId] = {}

    table.insert(conversations[playerId][pedId], {
        role = 'system',
        content = systemPrompt
    })
end


RegisterNetEvent("ai_ped:talk", function(pedNetId, pedModel, message)
    local src = source

    if not pedNetId or not pedModel or not message then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(pedNetId)
    if not entity or entity == 0 then
        return
    end

    -- Crear tabla del jugador si no existe
    conversations[src] = conversations[src] or {}

    -- Crear conversación para ese ped si no existe
    conversations[src][pedNetId] = conversations[src][pedNetId] or nil

    -- Si no existe conversación la iniciamos
    if not conversations[src][pedNetId] then
        setupConversation(src, pedNetId, pedModel)
    end

    -- Estado thinking
    Entity(entity).state:set('isThinking', true, true)

    -- Generar respuesta
    generateResponse(src, pedNetId, pedModel, message)
end)


AddEventHandler("playerDropped", function()
    conversations[source] = nil
end)


