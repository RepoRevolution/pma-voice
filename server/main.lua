Server = {}
Server.voiceData = {}
Server.radioData = {}
Server.callData = {}

local mappedChannels = {}
local function firstFreeChannel()
	for i = 1, 2048 do
		if not mappedChannels[i] then
			return i
		end
	end
	return 0
end

local function handleStateBagInitilization(source)
	local plyState = Player(source).state
    if not plyState.pmaVoiceInit then
        plyState:set('radio', GetConvarInt('voice_defaultRadioVolume', 60), true)
        plyState:set('rr_radio', GetConvarInt('voice_defaultRadioVolume', 60), true)
        plyState:set('call', GetConvarInt('voice_defaultCallVolume', 60), true)
        plyState:set('submix', nil, true)
        plyState:set('proximity', {}, true)
        plyState:set('callChannel', 0, true)
        plyState:set('radioChannels', {}, true)
        plyState:set('radioChannel', 0, true)
        plyState:set('voiceIntent', 'speech', true)
        plyState:set('pmaVoiceInit', true, false)
    end

	local assignedChannel = firstFreeChannel()
	plyState:set('assignedChannel', assignedChannel, true)
	if assignedChannel ~= 0 then
		mappedChannels[assignedChannel] = source
		Logger.verbose('[reuse] Assigned %s to channel %s', source, assignedChannel)
	else
		Logger.error('[reuse] Failed to find a free channel for %s', source)
	end
end

function Server.defaultTable(source)
	handleStateBagInitilization(source)
	return {
		radio = 0,
		call = 0,
		lastRadio = 0,
		lastCall = 0
	}
end

CreateThread(function()
	local plyTbl = GetPlayers()
	for i = 1, #plyTbl do
		local ply = tonumber(plyTbl[i])
        if ply then
		    Server.voiceData[ply] = Server.defaultTable(plyTbl[i])
        end
	end

	Wait(5000)

	local nativeAudio = GetConvar('voice_useNativeAudio', 'not-set')
	local _3dAudio = GetConvar('voice_use3dAudio', 'not-set')
	local _2dAudio = GetConvar('voice_use2dAudio', 'not-set')
	local sendingRangeOnly = GetConvar('voice_useSendingRangeOnly', 'not-set')

	if
		nativeAudio == 'not-set'
		and _3dAudio == 'not-set'
		and _2dAudio == 'not-set'
	then
		SetConvarReplicated('voice_useNativeAudio', 'true')
		if sendingRangeOnly == 'not-set' then
			SetConvarReplicated('voice_useSendingRangeOnly', 'true')
			Logger.info(
				'No convars detected for voice mode, defaulting to \'setr voice_useNativeAudio true\' and \'setr voice_useSendingRangeOnly true\'')
		else
			Logger.info('No voice mod detected, defaulting to \'setr voice_useNativeAudio true\'')
		end
	elseif sendingRangeOnly == 'not-set' then
		Logger.warn(
			"It's recommended to have 'voice_useSendingRangeOnly' set to true, you can do that with 'setr voice_useSendingRangeOnly true', this prevents players who directly join the mumble server from broadcasting to players.")
	end

	local radioVolume = GetConvarInt("voice_defaultRadioVolume", 30)
	local callVolume = GetConvarInt("voice_defaultCallVolume", 60)

	if
		radioVolume == 0 or radioVolume == 1 or
		callVolume == 0 or callVolume == 1
	then
		SetConvarReplicated("voice_defaultRadioVolume", '30')
		SetConvarReplicated("voice_defaultCallVolume", '60')
		for i = 1, 5 do
			Wait(5000)
			Logger.warn(
				"`voice_defaultRadioVolume` or `voice_defaultCallVolume` have their value set as a float, this is going to automatically be fixed but please update your convars.")
		end
	end
end)

AddEventHandler('playerJoining', function()
	if not Server.voiceData[source] then
		Server.voiceData[source] = Server.defaultTable(source)
	end
end)

AddEventHandler("playerDropped", function()
	local source = source
	local mappedChannel = Player(source).state.assignedChannel

	if Server.voiceData[source] then
		local plyData = Server.voiceData[source]

		if plyData.radio ~= 0 then
			RemovePlayerFromRadio(source, plyData.radio)
		end

		if plyData.call ~= 0 then
			RemovePlayerFromCall(source, plyData.call)
		end

		Server.voiceData[source] = nil
	end

	if mappedChannel then
		mappedChannels[mappedChannel] = nil
		Logger.verbose('[reuse] Unassigned %s from channel %s', source, mappedChannel)
	end
end)

if GetConvarInt('voice_externalDisallowJoin', 0) == 1 then
	AddEventHandler('playerConnecting', function(_, _, deferral)
		deferral.defer()
		Citizen.Wait(0)
		deferral.done('This server is not accepting connections.')
	end)
end

local function isValidPlayer(source)
	return Server.voiceData[source]
end
exports('isValidPlayer', isValidPlayer)

local function getPlayersInRadioChannel(channel)
	local returnChannel = Server.radioData[channel]
	if returnChannel then
		return returnChannel
	end
	return {}
end
exports('getPlayersInRadioChannel', getPlayersInRadioChannel)
exports('GetPlayersInRadioChannel', getPlayersInRadioChannel)