local callChannel = 0

RegisterNetEvent('pma-voice:syncCallData', function(callTable, channel)
	Client.callData = callTable
	HandleRadioAndCallInit()
end)

RegisterNetEvent('pma-voice:addPlayerToCall', function(plySource)
	ToggleVoice(plySource, true, 'call')
	Client.callData[plySource] = true
end)

RegisterNetEvent('pma-voice:removePlayerFromCall', function(plySource)
	if plySource == Client.serverId then
		for tgt, _ in pairs(Client.callData) do
			if tgt ~= Client.serverId then
				ToggleVoice(tgt, false, 'call')
			end
		end
		Client.callData = {}
		MumbleClearVoiceTargetPlayers(Shared.voiceTarget)
		AddVoiceTargets((Client.radioPressed and IsRadioEnabled()) and Client.radioData or {}, Client.callData)
	else
		Client.callData[plySource] = nil
		ToggleVoice(plySource, Client.radioData[plySource], 'call')
		if MumbleIsPlayerTalking(PlayerId()) then
			MumbleClearVoiceTargetPlayers(Shared.voiceTarget)
			AddVoiceTargets((Client.radioPressed and IsRadioEnabled()) and Client.radioData or {}, Client.callData)
		end
	end
end)

function SetCallChannel(channel)
	if GetConvarInt('voice_enableCalls', 1) ~= 1 then return end
	TriggerServerEvent('pma-voice:setPlayerCall', channel)
	callChannel = channel

	SendUIMessage({
		callInfo = channel
	})
end
exports('setCallChannel', SetCallChannel)
exports('SetCallChannel', SetCallChannel)

exports('addPlayerToCall', function(_call)
	local call = tonumber(_call)
	if call then
		SetCallChannel(call)
	end
end)

exports('removePlayerFromCall', function()
	SetCallChannel(0)
end)

RegisterNetEvent('pma-voice:clSetPlayerCall', function(_callChannel)
	if GetConvarInt('voice_enableCalls', 1) ~= 1 then return end
	callChannel = _callChannel
end)
