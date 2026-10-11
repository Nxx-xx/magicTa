/* Project-owned persistence adapter. Loaded inside the pinned Emscripten module.
 * Restore BEFORE main(), flush synchronously after a save and on wx.onHide.
 * Only touches this game's private /towerrealm-v1/userfs directory.
 */
function installTowerPersistence(Module, FS, GodotFS, api) {
  const disk = api.getFileSystemManager();
  const base = api.env.USER_DATA_PATH + '/towerrealm-v1';
  let roots = [];
  let lastError = '';
  function mkdir(path) {
    try { disk.accessSync(path); }
    catch (_) { disk.mkdirSync(path, true); }
  }
  function restore(path) {
    mkdir(base + path);
    FS.mkdirTree(path);
    for (const name of disk.readdirSync(base + path)) {
      if (name.endsWith('.wxwriting')) continue;
      const child = path + '/' + name;
      if (disk.statSync(base + child).isDirectory()) restore(child);
      else FS.writeFile(child, new Uint8Array(disk.readFileSync(base + child)));
    }
  }
  function persist(path) {
    mkdir(base + path);
    for (const name of FS.readdir(path)) {
      if (name === '.' || name === '..') continue;
      const child = path + '/' + name;
      if (FS.isDir(FS.stat(child).mode)) persist(child);
      else {
        const bytes = FS.readFile(child);
        const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
        disk.writeFileSync(base + child + '.wxwriting', buffer);
        disk.renameSync(base + child + '.wxwriting', base + child);
      }
    }
  }
  const bridge = {
    safeTop() {
      const info = api.getWindowInfo ? api.getWindowInfo() : api.getSystemInfoSync();
      const menu = api.getMenuButtonBoundingClientRect ? api.getMenuButtonBoundingClientRect() : {bottom: 0};
      return Math.max(info.safeArea ? info.safeArea.top : 0, menu.bottom || 0) + 8;
    },
    safeBottom() {
      const info = api.getWindowInfo ? api.getWindowInfo() : api.getSystemInfoSync();
      return (info.safeArea ? Math.max(0, info.windowHeight - info.safeArea.bottom) : 0) + 8;
    },
    flush() {
      try { roots.forEach(persist); lastError = ''; return true; }
      catch (error) { lastError = String(error); console.error('[TowerSave]', error); return false; }
    },
    error() { return lastError; }
  };
  Module['initFS'] = function(paths) {
    roots = paths.slice();
    if (roots.some(path => path !== '/userfs')) return Promise.reject(new Error('Unexpected persistent path'));
    try {
      roots.forEach(restore);
      // MEMFS directories are not IDBFS mounts; deinit must not unmount them.
      GodotFS._mount_points = [];
      GodotFS._idbfs = true;
      console.log('[TowerSave] restored before main');
      return Promise.resolve();
    } catch (error) { return Promise.reject(error); }
  };
  GodotFS.sync = function() {
    return Promise.resolve(bridge.flush() ? null : new Error(lastError));
  };
  GameGlobal.__towerPersistence = bridge;
  globalThis.__towerPersistence = bridge;
  if (GameGlobal.__adapter && GameGlobal.__adapter.window) GameGlobal.__adapter.window.__towerPersistence = bridge;
  api.onHide(() => bridge.flush());
  return bridge;
}
if (typeof module !== 'undefined') module.exports = installTowerPersistence;
