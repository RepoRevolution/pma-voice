---@param source number the player to remove from the call
---@param callChannel number the call channel to remove them from
function RemovePlayerFromCall(source, callChannel)
	Logger.verbose('[call] Removed %s from call %s', source, callChannel)

	Server.callData[callChannel] = Server.callData[callChannel] or {}
	for player, _ in pairs(Server.callData[callChannel]) do
		TriggerClientEvent('pma-voice:removePlayerFromCall', player, source)
	end
	Server.callData[callChannel][source] = nil
	Server.voiceData[source] = Server.voiceData[source] or Server.defaultTable(source)
	Server.voiceData[source].call = 0
end

---@param source number the player to add to the call
---@param callChannel number the call channel to add them to
function AddPlayerToCall(source, callChannel)
	Logger.verbose('[call] Added %s to call %s', source, callChannel)
	Server.callData[callChannel] = Server.callData[callChannel] or {}
	for player, _ in pairs(Server.callData[callChannel]) do
		if player ~= source then
			TriggerClientEvent('pma-voice:addPlayerToCall', player, source)
		end
	end
	Server.callData[callChannel][source] = true
	Server.voiceData[source] = Server.voiceData[source] or Server.defaultTable(source)
	Server.voiceData[source].call = callChannel
	TriggerClientEvent('pma-voice:syncCallData', source, Server.callData[callChannel])
end

---@param source number the player to set the call off
---@param _callChannel number the channel to set the player to (or 0 to remove them from any call channel)
local function setPlayerCall(source, _callChannel)
	if GetConvarInt('voice_enableCalls', 1) ~= 1 then return end
	Server.voiceData[source] = Server.voiceData[source] or Server.defaultTable(source)
	local isResource = GetInvokingResource()
	local plyVoice = Server.voiceData[source]
	local callChannel = tonumber(_callChannel)
	if not callChannel then
		if isResource then
			error(("'callChannel' expected 'number', got: %s"):format(type(_callChannel)))
		else
			return Logger.warn("%s sent a invalid call, 'callChannel' expected 'number', got: %s", source,
				type(_callChannel))
		end
	end
	if isResource then
		TriggerClientEvent('pma-voice:clSetPlayerCall', source, callChannel)
	end

	Player(source).state.callChannel = callChannel

	if callChannel ~= 0 and plyVoice.call == 0 then
		AddPlayerToCall(source, callChannel)
	elseif callChannel == 0 then
		RemovePlayerFromCall(source, plyVoice.call)
	elseif plyVoice.call > 0 then
		RemovePlayerFromCall(source, plyVoice.call)
        ---@diagnostic disable-next-line: param-type-mismatch
		AddPlayerToCall(source, callChannel)
	end
end
exports('setPlayerCall', setPlayerCall)

RegisterNetEvent('pma-voice:setPlayerCall', function(callChannel)
	setPlayerCall(source, callChannel)
end)