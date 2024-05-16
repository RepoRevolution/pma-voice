---@param source number the player to remove
---@param radioChannel number the current channel to remove them from
function RemovePlayerFromRadio(source, radioChannel)
	Logger.verbose('[radio] Removed %s from radio %s', source, radioChannel)
	Server.radioData[radioChannel] = Server.radioData[radioChannel] or {}
	for player, _ in pairs(Server.radioData[radioChannel]) do
		TriggerClientEvent('pma-voice:removePlayerFromRadio', player, source)
	end
	Server.radioData[radioChannel][source] = nil
	Server.voiceData[source] = Server.voiceData[source] or Server.defaultTable(source)
	Server.voiceData[source].radio = 0
end

if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
local radioChecks = {}

--- @param source number the source of the player
--- @param radioChannel number the channel they're trying to join
--- @return boolean if the user can join the channel
local function canJoinChannel(source, radioChannel)
	if radioChecks[radioChannel] then
		return radioChecks[radioChannel](source)
	end
	return true
end

---@param channel number the channel to add a check to
---@param cb function the function to execute the check on
local function addChannelCheck(channel, cb)
	local channelType = type(channel)
	local cbType = type(cb)
	if channelType ~= "number" then
		error(("'channel' expected 'number' got '%s'"):format(channelType))
	end
	if cbType ~= 'table' or not cb.__cfx_functionReference then
		error(("'cb' expected 'function' got '%s'"):format(cbType))
	end
	radioChecks[channel] = cb
	Logger.info("%s added a check to channel %s", GetInvokingResource(), channel)
end
exports('addChannelCheck', addChannelCheck)

local function radioNameGetter_orig(source)
	return GetPlayerName(source)
end
local radioNameGetter = radioNameGetter_orig

---@param cb function the function to execute the check on
local function overrideRadioNameGetter(channel, cb)
	local cbType = type(cb)
	if cbType == 'table' and not cb.__cfx_functionReference then
		error(("'cb' expected 'function' got '%s'"):format(cbType))
	end
	radioNameGetter = cb
	Logger.info("%s added a check to channel %s", GetInvokingResource(), channel)
end
exports('overrideRadioNameGetter', overrideRadioNameGetter)

---@param source number the player to add to the channel
---@param radioChannel number the channel to set them to
---@return boolean wasAdded if the player was successfuly added to the radio channel, or if it failed.
local function addPlayerToRadio(source, radioChannel)
	if not canJoinChannel(source, radioChannel) then
		TriggerClientEvent("pma-voice:radioChangeRejected", source)
		TriggerClientEvent('pma-voice:removePlayerFromRadio', source, source)
		return false
	end
	Logger.verbose('[radio] Added %s to radio %s', source, radioChannel)
	Server.radioData[radioChannel] = Server.radioData[radioChannel] or {}
	local plyName = radioNameGetter(source)
	for player, _ in pairs(Server.radioData[radioChannel]) do
		TriggerClientEvent('pma-voice:addPlayerToRadio', player, source, plyName)
	end
	Server.voiceData[source] = Server.voiceData[source] or Server.defaultTable(source)
	Server.voiceData[source].radio = radioChannel
	Server.radioData[radioChannel][source] = false
	TriggerClientEvent('pma-voice:syncRadioData', source, Server.radioData[radioChannel],
		GetConvarInt("voice_syncPlayerNames", 0) == 1 and plyName)
	return true
end

-- TODO: Implement this in a way that allows players to be on multiple channels
---@param source number the player to set the channel of
---@param _radioChannel number the radio channel to set them to (or 0 to remove them from radios)
local function setPlayerRadio(source, _radioChannel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	Server.voiceData[source] = Server.voiceData[source] or Server.defaultTable(source)
	local isResource = GetInvokingResource()
	local plyVoice = Server.voiceData[source]
	local radioChannel = tonumber(_radioChannel)
	if not radioChannel then
		-- only full error if its sent from another server-side resource
		if isResource then
			error(("'radioChannel' expected 'number', got: %s"):format(type(_radioChannel)))
		else
			return Logger.warn("%s sent a invalid radio, 'radioChannel' expected 'number', got: %s", source,
				type(_radioChannel))
		end
	end
	if isResource then
		-- got set in a export, need to update the client to tell them that their radio
		-- changed
		TriggerClientEvent('pma-voice:clSetPlayerRadio', source, radioChannel)
	end
	if radioChannel ~= 0 then
		if plyVoice.radio > 0 then
			RemovePlayerFromRadio(source, plyVoice.radio)
		end
		local wasAdded = addPlayerToRadio(source, radioChannel)
		Player(source).state.radioChannel = wasAdded and radioChannel or 0
	elseif radioChannel == 0 then
		RemovePlayerFromRadio(source, plyVoice.radio)
		Player(source).state.radioChannel = 0
	end
end
exports('setPlayerRadio', setPlayerRadio)

RegisterNetEvent('pma-voice:setPlayerRadio', function(radioChannel)
	setPlayerRadio(source, radioChannel)
end)

---@param talking boolean sets if the palyer is talking.
local function setTalkingOnRadio(talking)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	Server.voiceData[source] = Server.voiceData[source] or Server.defaultTable(source)
	local plyVoice = Server.voiceData[source]
	local radioTbl = Server.radioData[plyVoice.radio]
	if radioTbl then
		radioTbl[source] = talking
		Logger.verbose('[radio] Set %s to talking: %s on radio %s', source, talking, plyVoice.radio)
		for player, _ in pairs(radioTbl) do
			if player ~= source then
				TriggerClientEvent('pma-voice:setTalkingOnRadio', player, source, talking)
				Logger.verbose('[radio] Sync %s to let them know %s is %s', player, source,
					talking and 'talking' or 'not talking')
			end
		end
	end
end
RegisterNetEvent('pma-voice:setTalkingOnRadio', setTalkingOnRadio)

AddEventHandler("onResourceStop", function(resource)
	for channel, cfxFunctionRef in pairs(radioChecks) do
		local functionRef = cfxFunctionRef.__cfx_functionReference
		local functionResource = string.match(functionRef, resource)
		if functionResource then
			radioChecks[channel] = nil
			Logger.warn('Channel %s had its radio check removed because the resource that gave the checks stopped',
				channel)
		end
	end

	if type(radioNameGetter) == "table" then
		local radioRef = radioNameGetter.__cfx_functionReference
		if radioRef then
			local isResource = string.match(radioRef, resource)
			if isResource then
				radioNameGetter = radioNameGetter_orig
				Logger.warn(
					'Radio name getter is resetting to default because the resource that gave the cb got turned off')
			end
		end
	end
end)