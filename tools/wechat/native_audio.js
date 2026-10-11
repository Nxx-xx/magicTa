/* Native audio avoids unavailable AudioWorklet output on Android WeChat. */
function installTowerAudio(api, targetWindow) {
  const cues = new Set(['step', 'pickup', 'door', 'hit', 'victory', 'rescue', 'midpoint', 'echo', 'echo_curse', 'failure', 'failure_1', 'failure_2', 'failure_3']);
  const voices = new Set(['echo_1', 'echo_2', 'echo_3']);
  let current = null;
  // Keep the two short footfalls warm instead of creating/destroying a context
  // on every tile. They are independent of story and interaction sounds.
  const steps = new Map();
  function stepPlayer(cue) {
    let player = steps.get(cue);
    if (player) return player;
    player = api.createInnerAudioContext({useWebAudioImplement: false});
    player.obeyMuteSwitch = false;
    player.src = 'audio/native/' + cue + '.wav';
    player.onPlay(() => {});
    player.onEnded(() => {});
    player.onError(error => {
      console.error('[TowerAudio]', cue, error);
      if (steps.get(cue) === player) { steps.delete(cue); player.destroy(); }
    });
    steps.set(cue, player);
    return player;
  }
  function stopSteps() {
    for (const player of steps.values()) player.stop();
  }
  let diagnosticCount = 0;
  function stop() {
    stopSteps();
    if (current) {
      const old = current;
      current = null;
      old.stop();
      old.destroy();
    }
  }
  const bridge = {
    stop,
    stopSteps,
    prepareSteps() {
      if (typeof api.createInnerAudioContext !== 'function') return false;
      try {
        stepPlayer('step');
        stepPlayer('step_alt');
        return true;
      } catch (error) { console.error('[TowerAudio]', error); return false; }
    },
    playStep(cue, volume) {
      if (!['step', 'step_alt'].includes(cue)) return false;
      if (typeof api.createInnerAudioContext !== 'function') return false;
      try {
        const player = stepPlayer(cue);
        player.volume = Math.max(0, Math.min(1, Number(volume) || 0));
        player.stop();
        player.play();
        return true;
      } catch (error) { console.error('[TowerAudio]', error); return false; }
    },
    playCue(cue, volume, voice) {
      if (!(voice ? voices : cues).has(cue)) return false;
      if (typeof api.createInnerAudioContext !== 'function') return false;
      try {
        stop();
        const player = api.createInnerAudioContext({useWebAudioImplement: false});
        current = player;
        player.obeyMuteSwitch = false;
        player.volume = Math.max(0, Math.min(1, Number(volume) || 0));
        player.src = 'audio/native/' + cue + '.wav';
        player.onEnded(() => { if (current === player) { current = null; player.destroy(); } });
        player.onError(error => { console.error('[TowerAudio]', cue, error); if (current === player) stop(); });
        player.onPlay(() => { if (diagnosticCount++ < 8) console.log('[TowerAudio] playing', cue); });
        player.play();
        return true;
      } catch (error) { console.error('[TowerAudio]', error); return false; }
    }
  };
  targetWindow.__towerAudio = bridge;
  GameGlobal.__towerAudio = bridge;
  api.onHide(stop);
  return bridge;
}
if (typeof module !== 'undefined') module.exports = installTowerAudio;
