AddEventHandler('onClientResourceStart', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	print('Starting script initialization')

	local success = pcall(function()
		local micClicksKvp = GetResourceKvpString('pma-voice_enableMicClicks')
		if not micClicksKvp then
			SetResourceKvp('pma-voice_enableMicClicks', "true")
		else
			if micClicksKvp ~= 'true' and micClicksKvp ~= 'false' then
				error('Invalid Kvp, throwing error for automatic fix')
			end
			Client.micClicks = micClicksKvp
		end
	end)

	if not success then
		Logger.warn(
			'Failed to load resource Kvp, likely was inappropriately modified by another server, resetting the Kvp.')
		SetResourceKvp('pma-voice_enableMicClicks', "true")
		Client.micClicks = 'true'
	end

	SendUIMessage({
		uiEnabled = GetConvarInt("voice_enableUi", 1) == 1,
		voiceModes = json.encode(Config.voiceModes),
		voiceMode = Client.mode - 1
	})

	local radioChannel = LocalPlayer.state.radioChannel or 0
	local callChannel = LocalPlayer.state.callChannel or 0

	if radioChannel ~= 0 then
		SetRadioChannel(radioChannel)
	end

	if callChannel ~= 0 then
		SetCallChannel(callChannel)
	end
    
	if not LocalPlayer.state.disableRadio then
		LocalPlayer.state:set("disableRadio", 0, true)
	end

	print('Script initialization finished.')
end)
