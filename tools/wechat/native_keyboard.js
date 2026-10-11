// Native text input for Godot's canvas UI. Polling avoids retaining callbacks
// into GDScript after a panel is removed from the scene tree.
function installTowerKeyboard(api, targetWindow) {
  let serial = 0;
  let session = null;
  const required = ['showKeyboard', 'hideKeyboard', 'onKeyboardInput', 'offKeyboardInput',
    'onKeyboardConfirm', 'offKeyboardConfirm', 'onKeyboardComplete', 'offKeyboardComplete'];
  function detach(s) {
    for (const [name, handler] of s.listeners) api['off' + name](handler);
    s.listeners = [];
  }
  function finish(s, event, value) {
    if (session !== s || !s.active) return;
    if (typeof value === 'string') s.value = value.slice(0, s.limit);
    s.event = event;
    s.height = 0;
    s.active = false;
    s.dirty = true;
    detach(s);
  }
  function hide(id) {
    const s = session;
    if (!s || s.id !== id) return;
    session = null;
    detach(s);
    if (s.active) {
      try { api.hideKeyboard({}); } catch (_) {}
    }
  }
  const bridge = {
    available() { return required.every(name => typeof api[name] === 'function'); },
    show(value, maxLength) {
      if (!bridge.available()) return 0;
      if (session) hide(session.id);
      const s = {id: ++serial, value: String(value || ''), limit: Math.max(1, Number(maxLength) || 32),
        // Reserve the lower half until a native height event supplies the exact
        // value (older mini-game base libraries may not expose that event).
        event: 'input', height: 0.5, active: true, dirty: true, listeners: []};
      session = s;
      function listen(name, fn) {
        s.listeners.push([name, fn]);
        api['on' + name](fn);
      }
      try {
        listen('KeyboardInput', res => {
          if (session !== s || !s.active) return;
          s.value = String(res.value || '').slice(0, s.limit);
          s.dirty = true;
        });
        listen('KeyboardConfirm', res => finish(s, 'confirm', res.value));
        listen('KeyboardComplete', res => finish(s, 'complete', res.value));
        if (api.onKeyboardHeightChange && api.offKeyboardHeightChange) {
          listen('KeyboardHeightChange', res => {
            if (session !== s || !s.active) return;
            const info = api.getWindowInfo ? api.getWindowInfo() : api.getSystemInfoSync();
            s.height = Math.max(0, Math.min(1, (Number(res.height) || 0) / (info.windowHeight || 1)));
            s.dirty = true;
          });
        }
        api.showKeyboard({defaultValue: s.value, maxLength: s.limit, multiple: false,
          confirmHold: false, confirmType: 'done',
          fail: () => finish(s, 'error')});
      } catch (_) { finish(s, 'error'); }
      return s.id;
    },
    read(id) {
      if (!session || session.id !== id || !session.dirty) return '';
      session.dirty = false;
      return JSON.stringify({value: session.value, event: session.event, height: session.height});
    },
    hide
  };
  targetWindow.__towerKeyboard = bridge;
  GameGlobal.__towerKeyboard = bridge;
  if (api.onHide) api.onHide(() => {
    if (!session || !session.active) return;
    finish(session, 'complete');
    try { api.hideKeyboard({}); } catch (_) {}
  });
  return bridge;
}
if (typeof module !== 'undefined') module.exports = installTowerKeyboard;
