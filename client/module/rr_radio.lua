if GetResourceState('rr_radio') == 'missing' then return end

exports('updateUI', function(enabled, radioChannel)
    SendUIMessage({
        radioEnabled = enabled,
        radioChannel = radioChannel
    })
end)

exports('usingRadio', function(talking)
    Client.radioPressed = talking
end)

exports('updateVoiceTargets', function(radioData)
    AddVoiceTargets(radioData, Client.callData)
end)

exports('setTalkingOnRadio', function(playerId, talking)
    local enabled = talking or Client.callData[playerId]
    ToggleVoice(playerId, enabled, 'rr_radio')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == 'rr_radio' then
        exports['pma-voice']:updateUI(false, 0)
    end
end)