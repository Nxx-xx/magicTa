const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const root = process.argv[2] || 'tools/wechat';
const loaderSource = fs.readFileSync(`${root}/loader.js`, 'utf8').replace(/^import .*;\r?\n/gm, '').replace('export default Loader;', 'globalThis.Loader = Loader;');
const rendererSource = fs.readFileSync(`${root}/loading_screen.js`, 'utf8').replace(/export function /g, 'function ');

function fixture({ imageFails = false, imageHangs = false, packageFails = false, size = [390, 844], dpr = 3, gpuLimit = 8192, bufferScale = 1 } = {}) {
  const draws = [], events = [], frames = [], timers = new Map();
  let timerID = 0, nativeOwner = false, packageProgress, engineProgress;
  const ctx = new Proxy({}, { get(_, name) {
    if (name === 'createLinearGradient' || name === 'createRadialGradient') return () => ({addColorStop() {}});
    return (...args) => { if (name === 'fillText') draws.push(args); };
  }, set() { return true; } });
  let uploadedSize, viewport;
  const gl = new Proxy({ MAX_TEXTURE_SIZE: 0x0d33, MAX_RENDERBUFFER_SIZE: 0x84e8 }, { get(obj, name) {
    if (name === 'drawingBufferWidth') return canvas.width * bufferScale;
    if (name === 'drawingBufferHeight') return canvas.height * bufferScale;
    if (name in obj) return obj[name];
    if (name === 'getParameter') return parameter => [0x0d33, 0x84e8].includes(parameter) ? gpuLimit : 8;
    return (...args) => {
      if (['drawArrays', 'clear', 'deleteTexture'].includes(name)) assert.equal(nativeOwner, false, `loader ${name} after engine acquired GL`);
      if (name === 'deleteTexture') events.push('cleanup');
      if (name === 'texImage2D') uploadedSize = [args[5].width, args[5].height];
      if (name === 'viewport') viewport = args;
      if (name === 'drawArrays') {
        assert.deepEqual([canvas.width, canvas.height], size, 'native screen retains adapter dimensions while loading');
        assert.deepEqual(viewport, [0, 0, ...size], 'viewport must cover the visible screen without native DPR zoom');
        // The fullscreen quad maps the ENTIRE texture into this viewport,
        // even when native drawingBuffer dimensions report different units.
        frames.push(uploadedSize);
        viewport = null; // Every frame must restore the viewport.
      }
      return {};
    };
  } });
  const canvas = {getContext: () => gl};
  const window = {innerWidth: size[0], innerHeight: size[1],
    setTimeout: f => {timers.set(++timerID, f); return timerID;}, clearTimeout: id => timers.delete(id),
    setInterval: (f, ms) => {timers.set(++timerID, {f, ms}); return timerID;}, clearInterval: id => timers.delete(id)};
  const api = {
    createCanvas: () => ({getContext: () => ctx}),
    createImage: () => ({width: 941, height: 1672, set src(value) { if (!imageHangs) queueMicrotask(() => imageFails ? this.onerror() : this.onload()); }}),
    loadSubpackage(opts) {
      queueMicrotask(() => { packageProgress({progress: 80}); packageProgress({progress: 20}); packageFails ? opts.fail(Error('offline')) : opts.success(); });
      return {onProgressUpdate: fn => { packageProgress = fn; }};
    },
  };
  const global = {__adapter: {canvas, window}, __towerStartup: {mark() {}}, __towerPersistence: {flush() {}}};
  class Engine {
    constructor(config) { this.config = config; engineProgress = config.onProgress; }
    async init(path) { assert.equal(path, 'engine/godot'); engineProgress(8, 10); engineProgress(1, 10); }
    async preloadFile(path, target) { assert.equal(path, 'engine/godot.zip'); assert.equal(target, path); }
    async start() {
      assert.ok(events.includes('cleanup'));
      assert.deepEqual([canvas.width, canvas.height], size, 'restore logical dimensions BEFORE engine owns the canvas');
      assert.equal([...timers.values()].filter(t => t.ms === 80).length, 0); nativeOwner = true;
    }
    requestQuit() {}
  }
  global.Engine = Engine;
  const sandbox = { console: {log() {}, error() {}}, Float32Array, Date, Promise,
    GameGlobal: global, BRIDGE_GLOBAL_NAME: '__bridge', GodotSDK: class {set_engine() {}},
    PlatformRuntime: {global, requireCapabilities: () => api, getSystemInfo: () => ({pixelRatio: dpr, safeArea: {top: 47, bottom: size[1] - 34}})} };
  vm.createContext(sandbox); vm.runInContext(rendererSource + '\n' + loaderSource, sandbox);
  const loader = new sandbox.Loader();
  return {loader, draws, frames, timers, canvas, sandbox, lateProgress: () => { packageProgress({progress: 100}); engineProgress(10, 10); }};
}

(async () => {
  for (const size of [[320, 568], [390, 844], [540, 960], [900, 960]]) {
    const f = fixture({size});
    const a = f.loader.load(); assert.equal(a, f.loader.load(), 'single boot promise');
    await a;
    assert.equal(f.loader.state, 'running'); assert.equal(f.loader.progress, 100);
    assert.equal(f.canvas.width, size[0]); assert.equal(f.canvas.height, size[1]);
    assert.ok(f.frames.every(([w, h]) => w > size[0] && h > size[1] && w * h <= 4 * 1024 * 1024));
    const percentages = f.draws.filter(d => /^\d+%$/.test(d[0])).map(d => parseInt(d[0]));
    assert.ok(percentages.length > 3); assert.ok(percentages.every((p, i) => p < 100 && (!i || p >= percentages[i - 1])));
    f.lateProgress(); // callbacks may arrive after engine owns the canvas
    assert.equal(f.loader.progress, 100);
    f.loader.dispose(); assert.equal(f.timers.size, 0);
    const l = f.sandbox.loadingLayout(...size, {top: 47, bottom: size[1] - 34});
    assert.ok(l.barX > 0 && l.barX + l.barWidth < size[0]);
    assert.ok(l.barY + 40 * l.scale < size[1] - 34, 'footer above home indicator');
  }
  for (const dpr of [1, 2, 2.625, 3, Infinity, NaN]) {
    const f = fixture({dpr}); await f.loader.load();
    const effective = Number.isFinite(dpr) ? dpr : 1;
    assert.deepEqual(f.frames[0], [Math.floor(390 * effective), Math.floor(844 * effective)]);
    f.loader.dispose();
  }
  const limited = fixture({gpuLimit: 2048}); await limited.loader.load();
  assert.ok(limited.frames.every(([w, h]) => w <= 2048 && h <= 2048)); limited.loader.dispose();
  for (const bufferScale of [2, 3, 3.5]) {
    const native = fixture({bufferScale}); await native.loader.load(); native.loader.dispose();
  }
  const fallback = fixture({imageFails: true}); await fallback.loader.load();
  assert.ok(fallback.draws.some(d => d[0] === '塔境')); fallback.loader.dispose();
  const timeout = fixture({imageHangs: true}); const pending = timeout.loader.load();
  [...timeout.timers.values()].filter(t => typeof t === 'function').forEach(f => f());
  await pending; timeout.loader.dispose();
  const failed = fixture({packageFails: true}); await assert.rejects(failed.loader.load(), /offline/);
  assert.equal(failed.loader.state, 'failed'); assert.equal(failed.timers.size, 0);
  assert.ok(failed.draws.some(d => d[0] === '请退出后重试')); failed.loader.dispose();
  const disposed = fixture({imageHangs: true}); const boot = disposed.loader.load(); disposed.loader.dispose();
  await assert.rejects(boot, /disposed/); assert.equal(disposed.timers.size, 0);
  console.log('PASS: 4 layouts; stable native screen/viewport with DPR-scaled drawingBuffer; high-resolution texture at DPR 1/2/2.625/3; invalid DPR and GPU/memory bounds; engine handoff, progress, failure and lifecycle');
})().catch(e => { console.error(e); process.exitCode = 1; });
