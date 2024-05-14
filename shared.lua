Config = {}
Shared = {}
Shared.voiceTarget = 1
Shared.gameVersion = GetGameName()

if not IsDuplicityVersion() then
    Client = {}
	LocalPlayer = LocalPlayer
	Client.serverId = GetPlayerServerId(PlayerId())

	if Shared.gameVersion == "redm" then
		function CreateAudioSubmix(name)
			return Citizen.InvokeNative(0x658d2bc8, name, Citizen.ResultAsInteger())
		end

		function AddAudioSubmixOutput(submixId, outputSubmixId)
			Citizen.InvokeNative(0xAC6E290D, submixId, outputSubmixId)
		end

		function MumbleSetSubmixForServerId(serverId, submixId)
			Citizen.InvokeNative(0xFE3A3054, serverId, submixId)
		end

		function SetAudioSubmixEffectParamFloat(submixId, effectSlot, paramIndex, paramValue)
			Citizen.InvokeNative(0x9A209B3C, submixId, effectSlot, paramIndex, paramValue)
		end

		function SetAudioSubmixEffectParamInt(submixId, effectSlot, paramIndex, paramValue)
			Citizen.InvokeNative(0x77FAE2B8, submixId, effectSlot, paramIndex, paramValue)
		end

		function SetAudioSubmixEffectRadioFx(submixId, effectSlot)
			Citizen.InvokeNative(0xAAA94D53, submixId, effectSlot)
		end

		function SetAudioSubmixOutputVolumes(submixId, outputSlot, frontLeftVolume, frontRightVolume, rearLeftVolume,
											 rearRightVolume, channel5Volume, channel6Volume)
			Citizen.InvokeNative(0x825DC0D1, submixId, outputSlot, frontLeftVolume, frontRightVolume, rearLeftVolume,
				rearRightVolume, channel5Volume, channel6Volume)
		end
	end
end

Player = Player
Entity = Entity

if GetConvar('voice_useNativeAudio', 'false') == 'true' then
	Config.voiceModes = {
		{ 1.5, "Whisper" }, -- Whisper speech distance in gta distance units
		{ 3.0, "Normal" },  -- Normal speech distance in gta distance units
		{ 6.0, "Shouting" } -- Shout speech distance in gta distance units
	}
else
	Config.voiceModes = {
		{ 3.0,  "Whisper" }, -- Whisper speech distance in gta distance units
		{ 7.0,  "Normal" },  -- Normal speech distance in gta distance units
		{ 15.0, "Shouting" } -- Shout speech distance in gta distance units
	}
end

---@param func function
local function functionName(func)
    local info = debug.getinfo(func, 'n')
    return info and info.name or 'unknown function'
end

---@param level number
---@param ... any
local function consoleLog(level, ...)
    local args = {...}
    local formattedArgs = {}
    if type(level) ~= 'number' then return end

    table.insert(formattedArgs,
        (
            level == 1 and '[^2INFO^7]' or level == 2 and '[^9DEBUG^7]'
            or level == 3 and '[^6WARNING^7]' or '[^8ERROR^7]'
        )
    )

    for i = 1, #args do
        local arg = args[i]
        local argType = type(arg)

        local formattedArg
        if argType == 'table' then
            formattedArg = json.encode(arg)
        elseif argType == 'function' then
            formattedArg = functionName(arg)
        elseif argType == 'nil' then
            formattedArg = 'NULL'
        else formattedArg = tostring(arg) end

        table.insert(formattedArgs, formattedArg)
    end

    print(table.concat(formattedArgs, ' '))
end
function LOG(level, ...) consoleLog(level, ...) end

Logger = {
	log = function(message, ...)
		LOG(1, message:format(...))
	end,
	info = function(message, ...)
		if GetConvarInt('voice_debugMode', 0) >= 1 then
            LOG(2, message:format(...))
		end
	end,
	warn = function(message, ...)
        LOG(3, message:format(...))
	end,
	error = function(message, ...)
        LOG(4, message:format(...))
	end,
	verbose = function(message, ...)
		if GetConvarInt('voice_debugMode', 0) >= 4 then
            LOG(2, message:format(...))
		end
	end,
}

local function types(args)
	local argType = type(args[1])
	for i = 2, #args do
		local arg = args[i]
		if argType == arg then
			return true, argType
		end
	end
	return false, argType
end

---@param ... table
function Shared.checkTypes(...)
	local vars = { ... }
	for i = 1, #vars do
		local var = vars[i]
		local matchesType, varType = types(var)
		if not matchesType then
			table.remove(var, 1)
			error(("Invalid type sent to argument #%s, expected %s, got %s"):format(i, table.concat(var, "|"), varType))
		end
	end
end