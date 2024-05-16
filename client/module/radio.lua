local radioChannel = 0
local radioNames = {}
local disableRadioAnim = false

---@return boolean isEnabled if radioEnabled is true and LocalPlayer.state.disableRadio is 0 (no bits set)
function IsRadioEnabled()
	return Client.radioEnabled and LocalPlayer.state.disableRadio == 0
end

if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end

---@param radioTable table the table of the current players on the radio
---@param localPlyRadioName string the local players name
local function syncRadioData(radioTable, localPlyRadioName)
	Client.radioData = radioTable
	Logger.info('[radio] Syncing radio table.')
	if GetConvarInt('voice_debugMode', 0) >= 4 then
		print('-------- RADIO TABLE --------')
		LOG(2, json.encode(radioTable, { indent = true }))
		print('-----------------------------')
	end

	local isEnabled = IsRadioEnabled()
	if isEnabled then
		HandleRadioAndCallInit()
	end

	SendUIMessage({
		radioChannel = radioChannel,
		radioEnabled = isEnabled
	})

	if GetConvarInt("voice_syncPlayerNames", 0) == 1 then
		radioNames[Client.serverId] = localPlyRadioName
	end
end
RegisterNetEvent('pma-voice:syncRadioData', syncRadioData)

---@param plySource number the players server id.
---@param enabled boolean whether the player is talking or not.
local function setTalkingOnRadio(plySource, enabled)
	Client.radioData[plySource] = enabled
	if not IsRadioEnabled() then return Logger.info("[radio] Ignoring setTalkingOnRadio. radioEnabled: %s disableRadio: %s", Client.radioEnabled, LocalPlayer.state.disableRadio) end
	local enabled = enabled or Client.callData[plySource]
	ToggleVoice(plySource, enabled, 'radio')
	PlayMicClicks(enabled)
end
RegisterNetEvent('pma-voice:setTalkingOnRadio', setTalkingOnRadio)

---@param plySource number the players server id to add to the radio.
local function addPlayerToRadio(plySource, plyRadioName)
	Client.radioData[plySource] = false
	if GetConvarInt("voice_syncPlayerNames", 0) == 1 then
		radioNames[plySource] = plyRadioName
	end
	Logger.info('[radio] %s joined radio %s %s', plySource, radioChannel,
		Client.radioPressed and " while we were talking, adding them to targets" or "")
	if Client.radioPressed then
		AddVoiceTargets(Client.radioData, Client.callData)
	end
end
RegisterNetEvent('pma-voice:addPlayerToRadio', addPlayerToRadio)

---@param plySource number the players server id to remove from the radio.
local function removePlayerFromRadio(plySource)
	if plySource == Client.serverId then
		Logger.info('[radio] Left radio %s, cleaning up.', radioChannel)
		for tgt, _ in pairs(Client.radioData) do
			if tgt ~= Client.serverId then
				ToggleVoice(tgt, false, 'radio')
			end
		end

		SendUIMessage({
			radioChannel = 0,
			radioEnabled = Client.radioEnabled
		})

		radioNames = {}
		Client.radioData = {}
		AddVoiceTargets(Client.callData)
	else
		ToggleVoice(plySource, false, 'radio')
		if Client.radioPressed then
			Logger.info('[radio] %s left radio %s while we were talking, updating targets.', plySource, radioChannel)
			AddVoiceTargets(Client.radioData, Client.callData)
		else
			Logger.info('[radio] %s has left radio %s', plySource, radioChannel)
		end

		Client.radioData[plySource] = nil
		if GetConvarInt("voice_syncPlayerNames", 0) == 1 then
			radioNames[plySource] = nil
		end
	end
end
RegisterNetEvent('pma-voice:removePlayerFromRadio', removePlayerFromRadio)

RegisterNetEvent('pma-voice:radioChangeRejected', function()
	Logger.info("The server rejected your radio change.")
	radioChannel = 0
end)

---@param channel number the channel to set the player to, or 0 to remove them.
function SetRadioChannel(channel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	Shared.checkTypes({ channel, "number" })
	TriggerServerEvent('pma-voice:setPlayerRadio', channel)
	radioChannel = channel
end
exports('setRadioChannel', SetRadioChannel)
exports('SetRadioChannel', SetRadioChannel)

exports('removePlayerFromRadio', function()
	SetRadioChannel(0)
end)

---@param _radio number the channel to set the player to, or 0 to remove them.
exports('addPlayerToRadio', function(_radio)
	local radio = tonumber(_radio)
	if radio then
		SetRadioChannel(radio)
	end
end)

exports('toggleRadioAnim', function()
	disableRadioAnim = not disableRadioAnim
	TriggerEvent('pma-voice:toggleRadioAnim', disableRadioAnim)
end)

exports("setDisableRadioAnim", function(shouldDisable)
	disableRadioAnim = shouldDisable
end)

exports('getRadioAnimState', function()
	return disableRadioAnim
end)

local function isDead()
	if LocalPlayer.state.isDead then
		return true
	elseif IsPlayerDead(PlayerId()) then
		return true
	end
	return false
end

local function isRadioAnimEnabled()
	if
		GetConvarInt('voice_enableRadioAnim', 1) == 1
		and not (GetConvarInt('voice_disableVehicleRadioAnim', 0) == 1
			and IsPedInAnyVehicle(PlayerPedId(), false))
		and not disableRadioAnim then
		return true
	end
	return false
end

RegisterCommand('+radiotalk', function()
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	if isDead() then return end
	if not IsRadioEnabled() then return end
	if not Client.radioPressed then
		if radioChannel > 0 then
			Logger.info('[radio] Start broadcasting, update targets and notify server.')
			AddVoiceTargets(Client.radioData, Client.callData)
			TriggerServerEvent('pma-voice:setTalkingOnRadio', true)
			Client.radioPressed = true
			local shouldPlayAnimation = isRadioAnimEnabled()
			PlayMicClicks(true)
			if shouldPlayAnimation then
				RequestAnimDict('random@arrests')
			end
			CreateThread(function()
				TriggerEvent("pma-voice:radioActive", true)
				LocalPlayer.state:set("radioActive", true, true);
				local checkFailed = false
				while Client.radioPressed do
					if radioChannel < 0 or isDead() or not IsRadioEnabled() then
						checkFailed = true
						break
					end
					if shouldPlayAnimation and HasAnimDictLoaded("random@arrests") then
						if not IsEntityPlayingAnim(PlayerPedId(), "random@arrests", "generic_radio_enter", 3) then
							TaskPlayAnim(PlayerPedId(), "random@arrests", "generic_radio_enter", 8.0, 2.0, -1, 50, 2.0, false,
								false,
							false)
						end
					end
					SetControlNormal(0, 249, 1.0)
					SetControlNormal(1, 249, 1.0)
					SetControlNormal(2, 249, 1.0)
					Wait(0)
				end


				if checkFailed then
					Logger.info("Canceling radio talking as the checks have failed.")
					ExecuteCommand("-radiotalk")
				end
				if shouldPlayAnimation then
					RemoveAnimDict('random@arrests')
				end
			end)
		else
			Logger.info("Player tried to talk but was not on a radio channel")
		end
	end
end, false)

RegisterCommand('-radiotalk', function()
	if radioChannel > 0 and Client.radioPressed then
		Client.radioPressed = false
		MumbleClearVoiceTargetPlayers(Shared.voiceTarget)
		AddVoiceTargets(Client.callData)
		TriggerEvent("pma-voice:radioActive", false)
		LocalPlayer.state:set("radioActive", false, true);
		PlayMicClicks(false)
		if GetConvarInt('voice_enableRadioAnim', 1) == 1 then
			StopAnimTask(PlayerPedId(), "random@arrests", "generic_radio_enter", -4.0)
		end
		TriggerServerEvent('pma-voice:setTalkingOnRadio', false)
	end
end, false)

if Shared.gameVersion == 'fivem' then
	RegisterKeyMapping('+radiotalk', 'Talk over Radio', 'keyboard', GetConvar('voice_defaultRadio', 'LMENU'))
end

---@param _radioChannel number the radio channel to set the player to.
local function syncRadio(_radioChannel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	Logger.info('[radio] radio set serverside update to radio %s', radioChannel)
	radioChannel = _radioChannel
end
RegisterNetEvent('pma-voice:clSetPlayerRadio', syncRadio)

---@param wasRadioEnabled boolean whether radio is enabled or not
function HandleRadioEnabledChanged(wasRadioEnabled)
	if wasRadioEnabled then
		syncRadioData(Client.radioData, "")
	else
		removePlayerFromRadio(Client.serverId)
	end
end

---@param bit number the bit to add
local function addRadioDisableBit(bit)
	local curVal = LocalPlayer.state.disableRadio or 0
	curVal = curVal | bit
	LocalPlayer.state:set("disableRadio", curVal, true)
end
exports("addRadioDisableBit", addRadioDisableBit)

---@param bit number the bit to remove
local function removeRadioDisableBit(bit)
	local curVal = LocalPlayer.state.disableRadio or 0
	curVal = curVal & (~bit)
	LocalPlayer.state:set("disableRadio", curVal, true)
end
exports("removeRadioDisableBit", removeRadioDisableBit)