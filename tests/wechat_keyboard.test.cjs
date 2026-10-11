const assert = require('node:assert/strict');
const install = require('../tools/wechat/native_keyboard.js');
global.GameGlobal = {};
const listeners = {};
let options, hides = 0, background;
const api = {
  showKeyboard(value) { options = value; },
  hideKeyboard() { hides++; },
  getWindowInfo() { return {windowHeight: 800}; },
  onHide(fn) { background = fn; }
};
for (const event of ['KeyboardInput', 'KeyboardConfirm', 'KeyboardComplete', 'KeyboardHeightChange']) {
  listeners[event] = new Set();
  api['on' + event] = fn => listeners[event].add(fn);
  api['off' + event] = fn => listeners[event].delete(fn);
}
const emit = (event, value) => [...listeners[event]].forEach(fn => fn(value));
const target = {};
const bridge = install(api, target);
assert.equal(target.__towerKeyboard, bridge);
assert.equal(GameGlobal.__towerKeyboard, bridge);
assert.equal(bridge.available(), true);
let id = bridge.show('nx', 32);
assert.equal(options.defaultValue, 'nx');
assert.equal(options.maxLength, 32);
assert.equal(options.multiple, false);
assert.equal(options.confirmHold, false);
assert.equal(options.confirmType, 'done');
assert.equal(JSON.parse(bridge.read(id)).height, 0.5);
assert.equal(bridge.read(id), '');
emit('KeyboardInput', {value: 'NXX'});
emit('KeyboardHeightChange', {height: 320});
assert.deepEqual(JSON.parse(bridge.read(id)), {value: 'NXX', event: 'input', height: 0.4});
const staleInput = [...listeners.KeyboardInput][0];
const staleComplete = [...listeners.KeyboardComplete][0];
const unrelated = () => {};
api.onKeyboardInput(unrelated);
emit('KeyboardConfirm', {value: 'nxx'});
staleComplete({value: 'old'});
assert.deepEqual(JSON.parse(bridge.read(id)), {value: 'nxx', event: 'confirm', height: 0});
assert.equal(listeners.KeyboardInput.size, 1, 'only our listeners are removed');
assert.equal(listeners.KeyboardConfirm.size, 0);
bridge.hide(id);
assert.equal(bridge.read(id), '');
id = bridge.show('saved', 32);
staleInput({value: 'stale'});
assert.equal(JSON.parse(bridge.read(id)).value, 'saved');
emit('KeyboardComplete', {value: 'edited'});
assert.deepEqual(JSON.parse(bridge.read(id)), {value: 'edited', event: 'complete', height: 0});
bridge.hide(id);
id = bridge.show('cancel', 32);
bridge.hide(id);
assert.equal(hides, 1, 'closing panel hides active keyboard');
id = bridge.show('', 3);
emit('KeyboardInput', {value: '123456'});
assert.equal(JSON.parse(bridge.read(id)).value, '123');
background();
assert.equal(JSON.parse(bridge.read(id)).event, 'complete', 'background never activates code');
id = bridge.show('retry', 32);
options.fail({errMsg: 'showKeyboard:fail'});
assert.equal(JSON.parse(bridge.read(id)).event, 'error');
id = bridge.show('retry', 32);
assert.equal(JSON.parse(bridge.read(id)).event, 'input');
bridge.hide(id - 1);
emit('KeyboardInput', {value: 'still active'});
assert.equal(JSON.parse(bridge.read(id)).value, 'still active', 'stale disposal cannot close new keyboard');
bridge.hide(id);
api.showKeyboard = () => { throw new Error('unsupported runtime'); };
id = bridge.show('', 32);
assert.equal(JSON.parse(bridge.read(id)).event, 'error');
assert.equal(install({}, {}).available(), false);
assert.equal(install({}, {}).show('', 32), 0);
console.log('PASS: native keyboard input, confirm, dismiss, height, cleanup, stale callbacks, background and retry');
