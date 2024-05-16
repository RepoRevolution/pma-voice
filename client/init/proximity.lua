-- used when muted
local disableUpdates = false
local isListenerEnabled = false
local plyCoords = GetEntityCoords(PlayerPedId())
local proximity = MumbleGetTalkerProximity()
Client.currentTargets = {}

local function orig_addProximityCheck(ply)
	local tgtPed = GetPlayerPed(ply)
	local voiceRange = GetConvar('voice_useNativeAudio', 'false') == 'true' and proximity * 3 or proximity
	local distance = #(plyCoords - GetEntityCoords(tgtPed))
	return distance < voiceRange, distance
end
local addProximityCheck = orig_addProximityCheck

exports("overrideProximityCheck", function(fn)
	addProximityCheck = fn
end)

exports("resetProximityCheck", function()
	addProximityCheck = orig_addProximityCheck
end)

function AddNearbyPlayers()
	if disableUpdates then return end
	plyCoords = GetEntityCoords(PlayerPedId())
	proximity = MumbleGetTalkerProximity()
	Client.currentTargets = {}
	MumbleClearVoiceTargetChannels(Shared.voiceTarget)
	if LocalPlayer.state.disableProximity then return end
	MumbleAddVoiceChannelListen(LocalPlayer.state.assignedChannel)
	MumbleAddVoiceTargetChannel(Shared.voiceTarget, LocalPlayer.state.assignedChannel)

	for source, _ in pairs(Client.callData) do
		if source ~= Client.serverId then
			MumbleAddVoiceTargetChannel(Shared.voiceTarget, MumbleGetVoiceChannelFromServerId(source))
		end
	end

	local players = GetActivePlayers()
	for i = 1, #players do
		local ply = players[i]
		local serverId = GetPlayerServerId(ply)
		local shouldAdd, distance = addProximityCheck(ply)
		if shouldAdd then
			-- if distance then
			-- 	currentTargets[serverId] = distance
			-- else
			-- 	-- backwards compat, maybe remove in v7
			-- 	currentTargets[serverId] = 15.0
			-- end
			-- logger.verbose('Added %s as a voice target', serverId)
			MumbleAddVoiceTargetChannel(Shared.voiceTarget, MumbleGetVoiceChannelFromServerId(serverId))
		end
	end
end

local function setSpectatorMode(enabled)
	Logger.info('Setting spectate mode to %s', enabled)
	isListenerEnabled = enabled
	local players = GetActivePlayers()
	if isListenerEnabled then
		for i = 1, #players do
			local ply = players[i]
			local serverId = GetPlayerServerId(ply)
			if serverId == Client.serverId then goto skip_loop end
			Logger.verbose("Adding %s to listen table", serverId)
			MumbleAddVoiceChannelListen(MumbleGetVoiceChannelFromServerId(serverId))
			::skip_loop::
		end
	else
		for i = 1, #players do
			local ply = players[i]
			local serverId = GetPlayerServerId(ply)
			if serverId == Client.serverId then goto skip_loop end
			Logger.verbose("Removing %s from listen table", serverId)
			MumbleRemoveVoiceChannelListen(MumbleGetVoiceChannelFromServerId(serverId))
			::skip_loop::
		end
	end
end

RegisterNetEvent('onPlayerJoining', function(serverId)
	if isListenerEnabled then
		MumbleAddVoiceChannelListen(MumbleGetVoiceChannelFromServerId(serverId))
		Logger.verbose("Adding %s to listen table", serverId)
	end
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
	if isListenerEnabled then
		MumbleRemoveVoiceChannelListen(MumbleGetVoiceChannelFromServerId(serverId))
		Logger.verbose("Removing %s from listen table", serverId)
	end
end)

local listenerOverride = false
exports("setListenerOverride", function(enabled)
	Shared.checkTypes({ enabled, "boolean" })
	listenerOverride = enabled
end)

local lastTalkingStatus = false
local lastRadioStatus = false
local voiceState = "proximity"
CreateThread(function()
	while true do
		while not MumbleIsConnected() do
			Wait(100)
		end

		if GetConvarInt('voice_enableUi', 1) == 1 then
			local curTalkingStatus = MumbleIsPlayerTalking(PlayerId())
			if lastRadioStatus ~= Client.radioPressed or lastTalkingStatus ~= curTalkingStatus then
				lastRadioStatus = Client.radioPressed
				lastTalkingStatus = curTalkingStatus

				SendUIMessage({
					usingRadio = lastRadioStatus,
					talking = lastTalkingStatus
				})
			end
		end

		if voiceState == "proximity" then
			AddNearbyPlayers()
			local cam = GetConvarInt("voice_disableAutomaticListenerOnCamera", 0) ~= 1 and GetRenderingCam() or -1
			local isSpectating = NetworkIsInSpectatorMode() or cam ~= -1
			if not isListenerEnabled and (isSpectating or listenerOverride) then
				setSpectatorMode(true)
			elseif isListenerEnabled and not isSpectating and not listenerOverride then
				setSpectatorMode(false)
			end
		end

		Citizen.Wait(GetConvarInt('voice_refreshRate', 200))
	end
end)

exports("setVoiceState", function(_voiceState, channel)
	if _voiceState ~= "proximity" and _voiceState ~= "channel" then
		Logger.error("Didn't get a proper voice state, expected proximity or channel, got %s", _voiceState)
	end
	voiceState = _voiceState
	if voiceState == "channel" then
		Shared.checkTypes({ channel, "number" })
		-- 65535 is the highest a client id can go, so we add that to the base channel so we don't manage to get onto a players channel
		channel = channel + 65535
		MumbleSetVoiceChannel(channel)
		while MumbleGetVoiceChannelFromServerId(Client.serverId) ~= channel do
			Wait(250)
		end
		MumbleAddVoiceTargetChannel(Shared.voiceTarget, channel)
	elseif voiceState == "proximity" then
		HandleInitialState()
	end
end)

AddEventHandler("onClientResourceStop", function(resource)
	if type(addProximityCheck) == "table" then
		local proximityCheckRef = addProximityCheck.__cfx_functionReference
		if proximityCheckRef then
			local isResource = string.match(proximityCheckRef, resource)
			if isResource then
				addProximityCheck = orig_addProximityCheck
				Logger.warn(
					'Reset proximity check to default, the original resource [%s] which provided the function restarted',
					resource)
			end
		end
	end
end)

exports("addVoiceMode", function(distance, name)
	for i = 1, #Config.voiceModes do
		local voiceMode = Config.voiceModes[i]
		if voiceMode[2] == name then
			Logger.verbose("Already had %s, overwritting instead", name)
			voiceMode[1] = distance
			return
		end
	end
	Config.voiceModes[#Config.voiceModes + 1] = { distance, name }
end)

exports("removeVoiceMode", function(name)
	for i = 1, #Config.voiceModes do
		local voiceMode = Config.voiceModes[i]
		if voiceMode[2] == name then
			table.remove(Config.voiceModes, i)
			if Client.mode == i then
				local newMode = Config.voiceModes[1]
				Client.mode = 1
				SetProximityState(newMode[Client.mode], false)
			end
			return true
		end
	end

	return false
end)