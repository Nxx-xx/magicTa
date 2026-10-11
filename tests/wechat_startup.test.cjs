const assert = require('node:assert/strict');
const {installTowerStartupDiagnostics} = require('../tools/wechat/startup_diagnostics.js');
let stored;
const handlers = {};
const api = {
  getStorageSync: () => stored,
  setStorageSync: (_key, value) => { stored = JSON.parse(JSON.stringify(value)); },
  getSystemInfoSync: () => ({model: 'legacy', system: 'iOS 26.5.2'}),
  getDeviceInfo: () => ({model: 'iPhone 16', system: 'iOS 26.5.2'}),
  getAppBaseInfo: () => ({version: 'test-wechat', SDKVersion: 'test-sdk'}),
  onError: handler => { handlers.error = handler; },
  onUnhandledRejection: handler => { handlers.rejection = handler; },
  onMemoryWarning: handler => { handlers.memory = handler; },
};
const scope = {};
let session = installTowerStartupDiagnostics(api, scope, 'comparison');
session.mark('wasm-instantiate', 'engine/godot.wasm.br');
// Simulate native exit without a JS exception and reinstall on the next launch.
session = installTowerStartupDiagnostics(api, {}, 'next-launch');
assert.equal(session.previous.stage, 'wasm-instantiate');
assert.equal(session.previous.device.model, 'iPhone 16');
assert.equal(session.previous.device.wechat, 'test-wechat');
handlers.error('example exception');
assert.equal(stored.stage, 'js-error');
handlers.rejection({reason: new Error('rejected')});
assert.match(stored.events.at(-1).detail, /rejected/);
handlers.memory({level: 10});
assert.equal(stored.stage, 'memory-warning');
for (let i = 0; i < 30; i++) session.mark('event', 'x'.repeat(2000));
assert.equal(stored.events.length, 16);
assert.equal(stored.events[0].detail.length, 1024);
const fail = () => { throw new Error('storage quota / missing API'); };
const unavailable = {getStorageSync: fail, setStorageSync: fail, getDeviceInfo: fail, onError: fail};
assert.doesNotThrow(() => installTowerStartupDiagnostics(unavailable, {}, 'no-storage').mark('running'));
assert.doesNotThrow(() => installTowerStartupDiagnostics({}, {}, 'no-apis').mark('running'));
console.log('PASS: startup breadcrumbs survive a native exit; bounded events and unavailable storage do not block boot');
