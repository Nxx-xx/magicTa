/* Bounded, local startup breadcrumbs survive a native exit; no game saves or network. */
function installTowerStartupDiagnostics(api, scope, build) {
  const key = 'towerrealm.startup-diagnostics.v1';
  let previous = null;
  try { previous = api.getStorageSync(key) || null; } catch (_) {}
  function info(method) {
    try { return typeof api[method] === 'function' ? api[method]() || {} : {}; }
    catch (_) { return {}; }
  }
  const legacy = info('getSystemInfoSync');
  const device = Object.assign({}, legacy, info('getDeviceInfo'));
  const app = Object.assign({}, legacy, info('getAppBaseInfo'));
  const record = {
    build, startedAt: Date.now(),
    device: {model: device.model, system: device.system, platform: device.platform,
      wechat: app.version, SDKVersion: app.SDKVersion},
    stage: 'entry', events: []
  };
  function mark(stage, detail) {
    try {
      record.stage = String(stage).slice(0, 80);
      record.events.push({stage: record.stage, at: Date.now(),
        detail: String(detail == null ? '' : detail).slice(0, 1024)});
      record.events = record.events.slice(-16);
      if (typeof api.setStorageSync === 'function') api.setStorageSync(key, record);
    } catch (_) {} // A full storage quota must never prevent boot.
  }
  scope.__towerStartup = {mark, previous, current: record};
  try {
    console.log('[TowerStartup] previous run (a record alone does not prove a crash):', JSON.stringify(previous));
    console.log('[TowerStartup] device:', JSON.stringify(record.device), 'build:', build);
  } catch (_) {}
  function listen(method, handler) {
    try { if (typeof api[method] === 'function') api[method](handler); } catch (_) {}
  }
  listen('onError', error => mark('js-error', error));
  listen('onUnhandledRejection', event => mark('unhandled-rejection', event && event.reason));
  listen('onMemoryWarning', event => mark('memory-warning', event && event.level));
  mark('entry');
  return scope.__towerStartup;
}

if (typeof module !== 'undefined') module.exports = {installTowerStartupDiagnostics};
