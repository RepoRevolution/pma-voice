function HandleInitialState()
	local voiceModeData = Config.voiceModes[Client.mode]
	MumbleSetTalkerProximity(voiceModeData[1] + 0.0)
	MumbleClearVoiceTarget(Shared.voiceTarget)
	MumbleSetVoiceTarget(Shared.voiceTarget)
	MumbleSetVoiceChannel(LocalPlayer.state.assignedChannel)

	while MumbleGetVoiceChannelFromServerId(Client.serverId) ~= LocalPlayer.state.assignedChannel do
		Wait(250)
		MumbleSetVoiceChannel(LocalPlayer.state.assignedChannel)
	end

	MumbleAddVoiceTargetChannel(Shared.voiceTarget, LocalPlayer.state.assignedChannel)

	AddNearbyPlayers()
end

AddEventHandler('mumbleConnected', function(address, isReconnecting)
	Logger.info('Connected to mumble server with address of %s, is this a reconnect %s',
		GetConvarInt('voice_hideEndpoints', 1) == 1 and 'HIDDEN' or address, isReconnecting)

	Logger.log('Connecting to mumble, setting targets.')
	local voiceModeData = Config.voiceModes[Client.mode]
	LocalPlayer.state:set('proximity', {
		index = Client.mode,
		distance = voiceModeData[1],
		mode = voiceModeData[2],
	}, true)

	HandleInitialState()

	Logger.log('Finished connection logic')
end)

AddEventHandler('mumbleDisconnected', function(address)
	Logger.info('Disconnected from mumble server with address of %s',
		GetConvarInt('voice_hideEndpoints', 1) == 1 and 'HIDDEN' or address)
end)

AddEventHandler('pma-voice:settingsCallback', function(cb)
	cb(Config)
end)