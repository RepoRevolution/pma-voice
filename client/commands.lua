local wasProximityDisabledFromOverride = false
local disableProximityCycle = false

RegisterCommand('setvoiceintent', function(source, args)
	if GetConvarInt('voice_allowSetIntent', 1) == 1 then
		local intent = args[1]
		if intent == 'speech' then
			MumbleSetAudioInputIntent(`speech`)
		elseif intent == 'music' then
			MumbleSetAudioInputIntent(`music`)
		end
		LocalPlayer.state:set('voiceIntent', intent, true)
	end
end, false)

RegisterCommand('vol', function(_, args)
	if not args[1] then return end
    ---@diagnostic disable-next-line: param-type-mismatch
	SetVolume(tonumber(args[1]))
end, false)

exports('setAllowProximityCycleState', function(state)
	Shared.checkTypes({ state, "boolean" })
	disableProximityCycle = state
end)

function SetProximityState(proximityRange, isCustom)
	local voiceModeData = Config.voiceModes[Client.mode]
	MumbleSetTalkerProximity(proximityRange + 0.0)

	LocalPlayer.state:set('proximity', {
		index = Client.mode,
		distance = proximityRange,
		mode = isCustom and "Custom" or voiceModeData[2],
	}, true)

	SendUIMessage({
		voiceMode = isCustom and #Config.voiceModes or Client.mode - 1
	})
end

exports("overrideProximityRange", function(range, disableCycle)
	Shared.checkTypes({ range, "number" })
	SetProximityState(range, true)

	if disableCycle then
		disableProximityCycle = true
		wasProximityDisabledFromOverride = true
	end
end)

exports("clearProximityOverride", function()
	local voiceModeData = Config.voiceModes[Client.mode]
	SetProximityState(voiceModeData[1], false)

	if wasProximityDisabledFromOverride then
		disableProximityCycle = false
	end
end)

RegisterCommand('cycleproximity', function()
	if GetConvarInt('voice_enableProximityCycle', 1) ~= 1 or disableProximityCycle then return end
	local newMode = Client.mode + 1

	if newMode <= #Config.voiceModes then
		Client.mode = newMode
	else
		Client.mode = 1
	end

	SetProximityState(Config.voiceModes[Client.mode][1], false)
	TriggerEvent('pma-voice:setTalkingMode', Client.mode)
end, false)

if Shared.gameVersion == 'fivem' then
	RegisterKeyMapping('cycleproximity', '[PMA] Cycle proximity', 'keyboard', GetConvar('voice_defaultCycle', 'F11'))
end