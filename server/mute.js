let mutedPlayers = {}
RegisterCommand('muteply', (source, args) => {
	const mutePly = parseInt(args[0])
	const duration = parseInt(args[1]) || 900
	if (mutePly && exports[GetCurrentResourceName()].isValidPlayer(mutePly)) {
		const isMuted = !MumbleIsPlayerMuted(mutePly);
		Player(mutePly).state.muted = isMuted;
		MumbleSetPlayerMuted(mutePly, isMuted);
		emit('pma-voice:playerMuted', mutePly, source, isMuted, duration);
		if (mutedPlayers[mutePly]) {
			clearTimeout(mutedPlayers[mutePly]);
			MumbleSetPlayerMuted(mutePly, isMuted)
			Player(mutePly).state.muted = isMuted;
			return;
		}
		mutedPlayers[mutePly] = setTimeout(() => {
			MumbleSetPlayerMuted(mutePly, !isMuted)
			Player(mutePly).state.muted = !isMuted;
			delete mutedPlayers[mutePly]
		}, duration * 1000)
	}
}, true)