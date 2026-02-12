local humanPeds = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/human-peds.json'))
local conversations = {}

-- Functions

function generateResponse(playerId, pedNetId, pedModel, message)

    table.insert(conversations[playerId][pedNetId], {
        role = 'user',
        content = message
    })

    PerformHttpRequest('https://api.openai.com/v1/chat/completions', function(code, data)

        if code ~= 200 or not data then
            local entity = NetworkGetEntityFromNetworkId(pedNetId)
            if entity and entity ~= 0 then
                Entity(entity).state:set('isThinking', false, true)
            end
            return
        end

        local _data = json.decode(data)
        local response = _data.choices[1].message.content

        table.insert(conversations[playerId][pedNetId], {
            role = 'assistant',
            content = response
        })

        -- TTS REQUEST
        PerformHttpRequest('https://api.v8.unrealspeech.com/synthesisTasks', function(ttsCode, ttsData)

            local entity = NetworkGetEntityFromNetworkId(pedNetId)
            if not entity or entity == 0 then return end

            if ttsCode ~= 200 or not ttsData then
                Entity(entity).state:set('isThinking', false, true)
                return
            end

            local ttsJson = json.decode(ttsData)
            local ttsUrl = ttsJson?.SynthesisTask?.OutputUri

            if not ttsUrl then
                Entity(entity).state:set('isThinking', false, true)
                return
            end

            -- Estados sincronizados
            Entity(entity).state:set('lastSpeech', response, true)
            Entity(entity).state:set('isThinking', false, true)
            Entity(entity).state:set('isSpeaking', true, true)

            local coords = GetEntityCoords(entity)
            local soundName = "ped_tts_" .. pedNetId

            exports.xsound:PlayUrlPos(-1, soundName, ttsUrl, 0.5, coords, false)
            exports.xsound:Distance(-1, soundName, Config.RangoVoz)
            exports.xsound:setSoundDynamic(-1, soundName, true)
            exports.xsound:destroyOnFinish(-1, soundName, true)

            local duration = math.max(4000, math.min(15000, string.len(response) * 55))

            SetTimeout(duration, function()
                if DoesEntityExist(entity) then
                    Entity(entity).state:set('isSpeaking', false, true)
                    Entity(entity).state:set('lastSpeech', nil, true)
                end
            end)

        end, 'POST', json.encode({
            Text = response,
            VoiceId = Config.Voices[humanPeds[pedModel].gender],
            Bitrate = "192k",
            Speed = "0",
            Pitch = "1"
        }), {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = ('Bearer %s'):format(Config.TTSAPIKey),
        })

    end, 'POST', json.encode({
        model = Config.ChatGPTModel,
        messages = conversations[playerId][pedNetId],
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


RegisterNetEvent("rex_ia_npc:talk", function(pedNetId, pedModel, message)
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


