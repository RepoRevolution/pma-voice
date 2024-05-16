local isRadioModuleEnabled = GetConvarInt('voice_enableRadios', 1) == 1

AddStateBagChangeHandler("submix", "", function(bagName, _, value)
	local tgtId = tonumber(bagName:gsub('player:', ''), 10)
	if not tgtId then return end
    local state = Player(tgtId).state
	if value and not Client.submixIndicies[value] then
		return Logger.warn("Player %s applied submix %s but it isn't valid",
			tgtId, value)
	end
	if not value then
		if (isRadioModuleEnabled and not Client.radioData[tgtId] or not state.radioActive) and not Client.callData[tgtId] then
			Logger.info("Resetting submix for player %s", tgtId)
			MumbleSetSubmixForServerId(tgtId, -1)
		end
		return
	end
	Logger.info("%s had their submix set to %s", tgtId, value)
	MumbleSetSubmixForServerId(tgtId, Client.submixIndicies[value])
end)
