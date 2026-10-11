const assert = require('node:assert/strict');
const install = require('../tools/wechat/native_audio.js');
global.GameGlobal = {};
let hide, created = [];
const target = {};
const bridge = install({
  onHide: cb => { hide = cb; },
  createInnerAudioContext: options => {
    assert.equal(options.useWebAudioImplement, false);
    const p = { stopped: false, destroyed: false,
      stop() {this.stopped = true;}, destroy() {this.destroyed = true;},
      play() {this.played = true; this.onplay();},
      onPlay(cb) {this.onplay = cb;}, onEnded(cb) {this.onend = cb;}, onError(cb) {this.onerror = cb;}
    };
    created.push(p); return p;
  }
}, target);
assert.equal(bridge.playCue('../invalid', 1, false), false);
assert.equal(bridge.playCue('hit', 0.45, false), true);
assert.equal(created[0].src, 'audio/native/hit.wav');
assert.equal(created[0].volume, 0.45);
assert.equal(created[0].played, true);
assert.equal(bridge.playCue('echo_1', 0.3, true), true);
assert.equal(created[0].destroyed, true);
assert.equal(created[1].src, 'audio/native/echo_1.wav');
hide();
assert.equal(created[1].stopped, true);
assert.equal(created[1].destroyed, true);
bridge.playCue('pickup', 0.7, false);
assert.equal(created[2].played, true); // A new sound after returning from background.
created[2].onend();
assert.equal(created[2].destroyed, true);
assert.equal(target.__towerAudio, bridge);
console.log('PASS: native WAV routes, voice/effect volume, replacement cleanup, background stop and subsequent playback');

assert.equal(bridge.playStep('../invalid', 1), false);
const beforeWarm = created.length;
assert.equal(bridge.prepareSteps(), true);
assert.equal(created.length, beforeWarm + 2);
assert.equal(created.at(-1).played, undefined, 'warming never makes a sound');
assert.equal(bridge.prepareSteps(), true);
assert.equal(created.length, beforeWarm + 2, 'warming is idempotent');
const leftStep = created.at(-2);
const rightStep = created.at(-1);
assert.equal(bridge.playStep('step', 0.5), true);
assert.equal(leftStep.src, 'audio/native/step.wav');
assert.equal(bridge.playStep('step_alt', 0.4), true);
const count = created.length;
bridge.playStep('step', 0.6);
assert.equal(created.length, count, 'footstep contexts are reused');
assert.equal(leftStep.volume, 0.6);
assert.equal(rightStep.src, 'audio/native/step_alt.wav');
bridge.playCue('echo_1', 0.3, true);
const dialogue = created.at(-1);
bridge.playStep('step', 0.5);
assert.equal(dialogue.destroyed, false, 'footfall does not cut off dialogue');
hide();
assert.equal(leftStep.stopped, true);
assert.equal(rightStep.stopped, true);
assert.equal(dialogue.destroyed, true);
bridge.playStep('step_alt', 0.4);
assert.equal(created.length, count + 1, 'resume reuses warm footstep context');
console.log('PASS: alternating cached footfalls, separate voice channel, background stop and resume');
