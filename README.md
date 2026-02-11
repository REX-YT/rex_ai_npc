# rex_ia_npc

Sistema de NPCs con Inteligencia Artificial para FiveM.

Este script te permite a los jugadores hablar con peatones del mundo y recibir respuestas dinámicas generadas por OpenAI, con voz 3D usando UnrealSpeech.

Desarrollado por devrex.

---

## Características

- Conversaciones individuales por jugador y NPC
- Contexto dinámico (hora, clima y ubicación)
- Personalidad configurable por modelo
- Voz automática según género
- Audio 3D sincronizado con el ped
- Texto 3D sobre el NPC mientras habla
- Estados sincronizados (`isThinking`, `isSpeaking`)
- Compatible con ESX, QBCore y standalone
- Optimizado para servidores Roleplay

---

## Requisitos

### Dependencias obligatorias

Debes tener instalados:

- ox_lib (TextUI e inputDialog)  
  https://github.com/overextended/ox_lib

- sounity (audio 3D)

- cd_easytime (hora y clima dinámicamente)

- OneSync habilitado

---

### APIs necesarias

Este recurso utiliza servicios externos:

OpenAI  
https://platform.openai.com/

UnrealSpeech  
https://unrealspeech.com/

Necesitarás una API Key para cada servicio.