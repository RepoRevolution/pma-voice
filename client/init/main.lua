local mutedPlayers = {}

local volumes = {
	['radio'] = GetConvarInt('voice_defaultRadioVolume', 60) / 100,
    ['rr_radio'] = GetConvarInt('voice_defaultRadioVolume', 60) / 100,
	['call'] = GetConvarInt('voice_defaultCallVolume', 60) / 100,
	['click_on'] = GetConvarInt('voice_onClickVolume', 10) / 100,
	['click_off'] = GetConvarInt('voice_offClickVolume', 3) / 100,
}

Client.radioEnabled, Client.radioPressed, Client.mode = true, false, GetConvarInt('voice_defaultVoiceMode', 2)
Client.radioData, Client.callData = {}, {}
Client.submixIndicies = {}

local function updateVolumes(voiceTable, override)
	for serverId, talking in pairs(voiceTable) do
		if serverId == Client.serverId then goto skip_iter end
		MumbleSetVolumeOverrideByServerId(serverId, talking and override or -1.0)
		::skip_iter::
	end
end

---@param volumeType any
local function resyncVolume(volumeType, newVolume)
	if volumeType == "all" then
		resyncVolume("radio", newVolume)
		resyncVolume("call", newVolume)
	elseif volumeType == "radio" then
		updateVolumes(Client.radioData, newVolume)
	elseif volumeType == "call" then
		updateVolumes(Client.callData, newVolume)
	end
end

---@param volume number between 0 and 100
---@param volumeType string | nil the volume type (currently radio & call) to set the volume of (opt)
function SetVolume(volume, volumeType)
	Shared.checkTypes({ volume, "number" })
	local volumeFraction = volume / 100

	if volumeType then
		local volumeTbl = volumes[volumeType]
		if volumeTbl then
			LocalPlayer.state:set(volumeType, volume, true)
			volumes[volumeType] = volumeFraction
			resyncVolume(volumeType, volumeFraction)
		else
			error(('SetVolume got a invalid volume type %s'):format(volumeType))
		end
	else
		for volumeType, _ in pairs(volumes) do
			volumes[volumeType] = volumeFraction
			LocalPlayer.state:set(volumeType, volume, true)
		end
		resyncVolume("all", volumeFraction)
	end
end

exports('setRadioVolume', function(vol)
	SetVolume(vol, 'radio')
end)

exports('getRadioVolume', function()
	return volumes['radio'] * 100
end)

exports("setCallVolume", function(vol)
	SetVolume(vol, 'call')
end)

exports('getCallVolume', function()
	return volumes['call'] * 100
end)


-- default submix incase people want to fiddle with it.
-- freq_low = 389.0
-- freq_hi = 3248.0
-- fudge = 0.0
-- rm_mod_freq = 0.0
-- rm_mix = 0.16
-- o_freq_lo = 348.0
-- o_freq_hi = 4900.0

local radioEffectId = CreateAudioSubmix('Radio')
SetAudioSubmixEffectRadioFx(radioEffectId, 0)
-- This is a GetHashKey on purpose, backticks break treesitter in nvim :|
SetAudioSubmixEffectParamInt(radioEffectId, 0, GetHashKey('default'), 1)
SetAudioSubmixOutputVolumes(
	radioEffectId,
	0,
	1.0 --[[ frontLeftVolume ]],
	0.25 --[[ frontRightVolume ]],
	0.0 --[[ rearLeftVolume ]],
	0.0 --[[ rearRightVolume ]],
	1.0 --[[ channel5Volume ]],
	1.0 --[[ channel6Volume ]]
)
AddAudioSubmixOutput(radioEffectId, 0)
Client.submixIndicies['radio'] = radioEffectId

local callEffectId = CreateAudioSubmix('Call')
SetAudioSubmixOutputVolumes(
	callEffectId,
	1,
	0.10 --[[ frontLeftVolume ]],
	0.50 --[[ frontRightVolume ]],
	0.0 --[[ rearLeftVolume ]],
	0.0 --[[ rearRightVolume ]],
	1.0 --[[ channel5Volume ]],
	1.0 --[[ channel6Volume ]]
)
AddAudioSubmixOutput(callEffectId, 1)
Client.submixIndicies['call'] = callEffectId

exports("registerCustomSubmix", function(callback)
	local submixTable = callback()
	Shared.checkTypes({ submixTable, "table" })
	local submixName, submixId = submixTable[1], submixTable[2]
	Shared.checkTypes({ submixName, "string" }, { submixId, "number" })
	Logger.info("Creating submix %s with submixId %s", submixName, submixId)
	Client.submixIndicies[submixName] = submixId
end)
TriggerEvent("pma-voice:registerCustomSubmixes")

---@param type string either "call" or "radio"
---@param effectId number submix id returned from CREATE_AUDIO_SUBMIX
exports("setEffectSubmix", function(type, effectId)
	Shared.checkTypes({ type, "string" }, { effectId, "number" })
	if Client.submixIndicies[type] then
		Client.submixIndicies[type] = effectId
	end
end)

local function restoreDefaultSubmix(plyServerId)
	local submix = Player(plyServerId).state.submix
	local submixEffect = Client.submixIndicies[submix]
	if not submix or not submixEffect then
		MumbleSetSubmixForServerId(plyServerId, -1)
		return
	end
	MumbleSetSubmixForServerId(plyServerId, submixEffect)
end

local disableSubmixReset = {}
---@param plySource number the players server id to override the volume for
---@param enabled boolean if the players voice is getting activated or deactivated
---@param moduleType string the volume & submix to use for the voice.
function ToggleVoice(plySource, enabled, moduleType)
	if mutedPlayers[plySource] then return end
	Logger.verbose('[main] Updating %s to talking: %s with submix %s', plySource, enabled, moduleType)
	local distance = Client.currentTargets[plySource]
	if enabled and (not distance or distance > 4.0) then
		MumbleSetVolumeOverrideByServerId(plySource, enabled and volumes[moduleType])
		if GetConvarInt('voice_enableSubmix', 1) == 1 then
			if moduleType then
				disableSubmixReset[plySource] = true
				if Client.submixIndicies[moduleType] then
					MumbleSetSubmixForServerId(plySource, Client.submixIndicies[moduleType])
				end
			else
				restoreDefaultSubmix(plySource)
			end
		end
	elseif not enabled then
		if GetConvarInt('voice_enableSubmix', 1) == 1 then
			disableSubmixReset[plySource] = nil
			SetTimeout(250, function()
				if not disableSubmixReset[plySource] then
					restoreDefaultSubmix(plySource)
				end
			end)
		end
		MumbleSetVolumeOverrideByServerId(plySource, -1.0)
	end
end

---@diagnostic disable-next-line: undefined-doc-param
---@param targets table expects multiple tables to be sent over
function AddVoiceTargets(...)
	local targets = { ... }
	local addedPlayers = {
		[Client.serverId] = true
	}

	for i = 1, #targets do
		for id, _ in pairs(targets[i]) do
			-- we don't want to log ourself, or listen to ourself
			if addedPlayers[id] and id ~= Client.serverId then
				Logger.verbose('[main] %s is already target don\'t re-add', id)
				goto skip_loop
			end
			if not addedPlayers[id] then
				Logger.verbose('[main] Adding %s as a voice target', id)
				addedPlayers[id] = true
				MumbleAddVoiceTargetPlayerByServerId(Shared.voiceTarget, id)
			end
			::skip_loop::
		end
	end
end

---@param clickType boolean whether to play the 'on' or 'off' click.
function PlayMicClicks(clickType)
	if Client.micClicks ~= 'true' then return Logger.verbose("Not playing mic clicks because client has them disabled") end

	SendUIMessage({
		sound = (clickType and "audio_on" or "audio_off"),
		volume = (clickType and volumes['click_on'] or volumes['click_off'])
	})
end

exports('isPlayerMuted', function(source)
	return mutedPlayers[source]
end)

exports('getMutedPlayers', function()
	return mutedPlayers
end)

---@param source number the player to mute
local function toggleMutePlayer(source)
	if mutedPlayers[source] then
		mutedPlayers[source] = nil
		MumbleSetVolumeOverrideByServerId(source, -1.0)
	else
		mutedPlayers[source] = true
		MumbleSetVolumeOverrideByServerId(source, 0.0)
	end
end
exports('toggleMutePlayer', toggleMutePlayer)

---@param type string what voice property you want to change (only takes 'radioEnabled' and 'micClicks')
---@param value any the value to set the type to.
local function setVoiceProperty(type, value)
	if type == "radioEnabled" and GetConvarInt('voice_enableRadios', 1) == 1 then
		Client.radioEnabled = value
		HandleRadioEnabledChanged(value)

		SendUIMessage({
			radioEnabled = value
		})
	elseif type == "micClicks" then
		local val = tostring(value)
		Client.micClicks = val
		SetResourceKvp('pma-voice_enableMicClicks', val)
	end
end
exports('setVoiceProperty', setVoiceProperty)
exports('SetMumbleProperty', setVoiceProperty)
exports('SetTokoProperty', setVoiceProperty)

local externalAddress = ''
local externalPort = 0
CreateThread(function()
	while true do
		Wait(500)
		if GetConvar('voice_externalAddress', '') ~= externalAddress or GetConvarInt('voice_externalPort', 0) ~= externalPort then
			externalAddress = GetConvar('voice_externalAddress', '')
			externalPort = GetConvarInt('voice_externalPort', 0)
			MumbleSetServerAddress(GetConvar('voice_externalAddress', ''), GetConvarInt('voice_externalPort', 0))
		end
	end
end)

if Shared.gameVersion == 'redm' then
	CreateThread(function()
		while true do
			if IsControlJustPressed(0, 0xA5BDCD3C --[[ Right Bracket ]]) then
				ExecuteCommand('cycleproximity')
			end
			if IsControlJustPressed(0, 0x430593AA --[[ Left Bracket ]]) then
				ExecuteCommand('+radiotalk')
			elseif IsControlJustReleased(0, 0x430593AA --[[ Left Bracket ]]) then
				ExecuteCommand('-radiotalk')
			end
			Citizen.Wait(0)
		end
	end)
end

function HandleRadioAndCallInit()
	for tgt, enabled in pairs(Client.radioData) do
		if tgt ~= Client.serverId then
			ToggleVoice(tgt, enabled, 'radio')
		end
	end

	for tgt, _ in pairs(Client.callData) do
		if tgt ~= Client.serverId then
			ToggleVoice(tgt, true, 'call')
		end
	end
end