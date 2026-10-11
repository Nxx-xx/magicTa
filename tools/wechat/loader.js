/**
 * Godot engine loader for mini games.
 *
 * Handles: loading screen → engine subpackage → FS restore/init → boot Godot → auto-sync.
 */

import "./libs/godot";
import { BRIDGE_GLOBAL_NAME, GodotSDK } from "./libs/sdk";
import { PlatformRuntime } from "./platform_runtime";
import { drawLoadingScreen } from "./loading_screen";

const _api = PlatformRuntime.requireCapabilities(
  ["canvas", "fileSystem", "image", "lifecycle", "subpackage", "windowInfo"],
  "engine loader",
);
const _global = PlatformRuntime.global;

const LoaderConfig = {
  background: "images/loading-background.jpg",
};

const fallbackCrypto = {
  // Compatibility fallback only. Preserve a native crypto implementation
  // whenever the host provides one.
  getRandomValues(view) {
    for (let i = 0; i < view.length; i++) view[i] = Math.floor(Math.random() * 256);
    return view;
  },
};

class FakeBlob {
  constructor(data, opts) {
    this.data = data || [];
    this.type = opts?.type || "";
    this.size = this.data.reduce((t, i) => t + (i.length || 0), 0);
  }
}

const godotSdk = new GodotSDK();

function _safeSet(obj, key, value) {
  if (!obj) return false;
  try {
    const desc = Object.getOwnPropertyDescriptor(obj, key);
    if (desc && !desc.writable && !desc.configurable) return obj[key] === value;
    Object.defineProperty(obj, key, { value, configurable: true, writable: true });
  } catch (_) { /* read-only in this runtime — skip */ }
  return obj[key] === value;
}

if (!_global.crypto || typeof _global.crypto.getRandomValues !== "function") {
  _safeSet(_global, "crypto", fallbackCrypto);
}
if (!globalThis.crypto || typeof globalThis.crypto.getRandomValues !== "function") {
  _safeSet(globalThis, "crypto", fallbackCrypto);
}
_safeSet(_global, "Blob", FakeBlob);
const _bridgeTargets = [_global, globalThis];
if (_global.__adapter && _global.__adapter.window) {
  _bridgeTargets.push(_global.__adapter.window);
}
for (const target of [...new Set(_bridgeTargets)]) {
  if (!_safeSet(target, BRIDGE_GLOBAL_NAME, godotSdk)) {
    throw new Error(`[Loader] Cannot register versioned bridge ${BRIDGE_GLOBAL_NAME}`);
  }
  // Backward-compatible alias for projects that access the JavaScript object
  // directly. GDScript uses the versioned name and performs an ABI handshake.
  _safeSet(target, "godotSdk", godotSdk);
}

// Use __adapter.canvas which has properly wrapped addEventListener/getContext,
// even when GameGlobal.canvas is a non-configurable native getter that we can't replace.
const _canvas = (_global.__adapter && _global.__adapter.canvas) || _global.canvas || _api.createCanvas();
const _window = (_global.__adapter && _global.__adapter.window) || _global.window || globalThis;
console.log("[Loader] canvas source:", _global.__adapter?.canvas ? "__adapter.canvas" : "GameGlobal.canvas");
console.log("[Loader] canvas.addEventListener:", typeof _canvas.addEventListener);

class Loader {
  constructor(config) {
    this.config = { ...LoaderConfig, ...config };
    const info = PlatformRuntime.getSystemInfo();
    const reportedDpr = Number(info.pixelRatio);
    const loadingDpr = Number.isFinite(reportedDpr) ? Math.max(1, reportedDpr) : 1;
    const logicalWidth = Math.max(1, Number(_window.innerWidth) || 1);
    const logicalHeight = Math.max(1, Number(_window.innerHeight) || 1);
    this.progress = 0;
    this.state = "idle";
    this.engine = null;
    this._loadPromise = null;
    this._syncTimer = null;
    this._loadingSurfaceCleaned = false;
    this._loadingTimer = null;
    this._ownsSurface = true;
    this._safeArea = info.safeArea || {};
    this._width = logicalWidth;
    this._height = logicalHeight;

    _global.__towerStartup.mark("webgl-context");
    this.screenCtx = _canvas.getContext("webgl2");
    // Keep the native screen on the adapter's logical-pixel contract. Unlike a
    // browser canvas, native GL can expose a physical drawingBuffer while its
    // viewport still uses the adapter's canvas units. Multiplying the screen
    // by DPR as well can zoom and clip the loading page on phones.
    // Supersample only the offscreen artwork, bounded by GPU/memory limits.
    const gl = this.screenCtx;
    const textureLimit = Number(gl.getParameter(gl.MAX_TEXTURE_SIZE)) || 4096;
    const bufferLimit = Number(gl.getParameter(gl.MAX_RENDERBUFFER_SIZE)) || 4096;
    const edgeLimit = Math.min(textureLimit, bufferLimit, 4096);
    const renderScale = Math.min(loadingDpr, edgeLimit / logicalWidth,
      edgeLimit / logicalHeight, Math.sqrt(4 * 1024 * 1024 / (logicalWidth * logicalHeight)));
    const pixelWidth = Math.max(1, Math.floor(logicalWidth * renderScale));
    const pixelHeight = Math.max(1, Math.floor(logicalHeight * renderScale));
    this.loadingCanvas = _api.createCanvas();
    this.loadingCtx = this.loadingCanvas.getContext("2d");
    this.loadingCanvas.width = pixelWidth;
    this.loadingCanvas.height = pixelHeight;
    _canvas.width = logicalWidth;
    _canvas.height = logicalHeight;
    this.loadingCtx.scale(pixelWidth / logicalWidth, pixelHeight / logicalHeight);
    this.loadingCtx.imageSmoothingEnabled = true;
    this.loadingCtx.imageSmoothingQuality = "high";
    _global.__towerStartup.mark("loading-resolution", `${pixelWidth}x${pixelHeight} / ${logicalWidth}x${logicalHeight}`);

    this.bgImage = _api.createImage();
    // Subscribe before assigning src: native images can resolve from cache.
    this._imageReady = new Promise(resolve => {
      let settled = false;
      const finish = (ok) => {
        if (settled) return;
        settled = true;
        this._imageLoaded = ok;
        _window.clearTimeout(this._imageTimeout);
        resolve();
      };
      this.bgImage.onload = () => finish(true);
      this.bgImage.onerror = () => finish(false);
      this._imageTimeout = _window.setTimeout(() => finish(false), 2500);
      this._cancelImage = () => finish(false);
      this.bgImage.src = this.config.background;
      if (this.bgImage.complete && this.bgImage.width > 0) finish(true);
    });

    const [tex, clean] = this._initWebgl();
    this.screenTexture = tex;
    this.cleanWebgl = clean;
  }

  async loadSubpackages() {
    console.log("[Loader] await loadSubpackage('engine')...");
    await new Promise((resolve, reject) => {
      const task = _api.loadSubpackage({ name: "engine", success: resolve, fail: reject });
      if (task && typeof task.onProgressUpdate === "function") {
        task.onProgressUpdate(event => this._setProgress(5 + Math.max(0, Math.min(100, Number(event.progress) || 0)) * 0.70));
      }
    });
    console.log("[Loader] await loadSubpackage('engine') done");
    this._setProgress(75);
  }

  _setProgress(value) {
    if (this.state !== "loading" || !this._ownsSurface) return;
    // Stage-weighted actual progress, never a timer that pretends to load.
    this.progress = Math.max(this.progress, Math.min(98, Number(value) || 0));
    this._drawLoading();
  }

  _drawLoading() {
    if (!this._ownsSurface || this._loadingSurfaceCleaned) return;
    drawLoadingScreen(this.loadingCtx, this._imageLoaded ? this.bgImage : null,
      this._width, this._height, this.progress,
      { safeArea: this._safeArea, time: Date.now(), failed: this.state === "failed" });
    this._blit();
  }

  _initWebgl() {
    const gl = this.screenCtx;
    const vsSrc = `attribute vec4 a_position; attribute vec2 a_texCoord; varying vec2 v_texCoord;
      void main() { gl_Position = a_position; v_texCoord = a_texCoord; }`;
    const fsSrc = `precision mediump float; varying vec2 v_texCoord; uniform sampler2D u_texture;
      void main() { gl_FragColor = texture2D(u_texture, v_texCoord); }`;
    const compile = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; };
    const vs = compile(gl.VERTEX_SHADER, vsSrc), fs = compile(gl.FRAGMENT_SHADER, fsSrc);
    const prog = gl.createProgram(); gl.attachShader(prog, vs); gl.attachShader(prog, fs); gl.linkProgram(prog); gl.useProgram(prog);

    const verts = new Float32Array([-1,1,0,0, -1,-1,0,1, 1,-1,1,1, -1,1,0,0, 1,-1,1,1, 1,1,1,0]);
    const buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.bufferData(gl.ARRAY_BUFFER, verts, gl.STATIC_DRAW);
    const posL = gl.getAttribLocation(prog, "a_position"); gl.vertexAttribPointer(posL, 2, gl.FLOAT, false, 16, 0); gl.enableVertexAttribArray(posL);
    const texL = gl.getAttribLocation(prog, "a_texCoord"); gl.vertexAttribPointer(texL, 2, gl.FLOAT, false, 16, 8); gl.enableVertexAttribArray(texL);

    const tex = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.viewport(0, 0, _canvas.width, _canvas.height);

    const clean = () => {
      for (let i = 0; i < gl.getParameter(gl.MAX_VERTEX_ATTRIBS); i++) gl.disableVertexAttribArray(i);
      gl.deleteTexture(tex); gl.deleteShader(vs); gl.deleteShader(fs); gl.deleteProgram(prog);
      gl.deleteBuffer(buf); gl.useProgram(null);
      gl.bindBuffer(gl.ARRAY_BUFFER, null); gl.bindTexture(gl.TEXTURE_2D, null);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.bindRenderbuffer(gl.RENDERBUFFER, null);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT);
      gl.viewport(0, 0, _canvas.width, _canvas.height);
    };
    return [tex, clean];
  }

  _blit() {
    const gl = this.screenCtx;
    // Reassert the full visible viewport; native drawingBuffer dimensions need
    // not use the same units as the adapter canvas (or update synchronously).
    gl.viewport(0, 0, _canvas.width, _canvas.height);
    gl.bindTexture(gl.TEXTURE_2D, this.screenTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, this.loadingCanvas);
    gl.clearColor(0, 0, 0, 1); gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }

  load() {
    if (this.state === "disposed") {
      return Promise.reject(new Error("[Loader] Cannot load after dispose()"));
    }
    if (!this._loadPromise) {
      this.state = "loading";
      this._drawLoading();
      this._loadingTimer = _window.setInterval(() => this._drawLoading(), 80);
      this._loadPromise = this._loadOnce();
    }
    return this._loadPromise;
  }

  async _loadOnce() {
    try {
      console.log("[Loader] ▶ 开始加载流程");

      console.log("[Loader] 1/6 加载图片资源...");
      _global.__towerStartup.mark("loading-images");
      await this._imageReady;
      this._assertNotDisposed();

      console.log("[Loader] 2/6 图片加载完成，开始加载引擎子包...");
      this._setProgress(5);
      _global.__towerStartup.mark("engine-subpackage");
      await this.loadSubpackages();
      this._assertNotDisposed();

      console.log("[Loader] 3/6 子包加载完成，初始化引擎...");
      const _Engine = _global.Engine || globalThis.Engine || null;
      console.log("[Loader]     Engine 类:", _Engine ? "已找到" : "未找到!");
      if (!_Engine) throw new Error("Engine not found – godot.js may not have loaded correctly");
      const engine = new _Engine({
        canvas: _canvas,
        executable: "engine/godot",
        mainPack: "engine/godot.zip",
        args: ["--main-pack", "engine/godot.zip"],
        onProgress: (loaded, total) => {
          if (total > 0) this._setProgress(75 + Math.min(1, loaded / total) * 20);
        },
      });
      _global.engine = engine;
      this.engine = engine;
      godotSdk.set_engine(engine);

      console.log("[Loader] 4/6 初始化引擎与游戏资源...");
      console.log("[Loader]     canvas:", _canvas ? `${_canvas.width}x${_canvas.height}` : "null");
      const ctx = _canvas.getContext("webgl2");
      console.log("[Loader]     WebGL2 context:", ctx ? "OK" : "FAILED (null)");
      if (ctx) {
        console.log("[Loader]     GL_RENDERER:", ctx.getParameter?.(ctx.RENDERER));
        console.log("[Loader]     GL_VERSION:", ctx.getParameter?.(ctx.VERSION));
      }

      _global.__towerStartup.mark("engine-start");
      // Equivalent to startGame, split at the documented init/preload/start
      // boundary so our GL timer and resources end BEFORE Godot owns canvas.
      await Promise.all([engine.init("engine/godot"), engine.preloadFile("engine/godot.zip", "engine/godot.zip")]);
      this._assertNotDisposed();
      this._setProgress(98);
      this._cleanupLoadingSurface();
      await engine.start();
      this._assertNotDisposed();
      this.progress = 100;

      console.log("[Loader] 5/6 engine.start() 完成，设置文件同步...");

      this._syncTimer = _window.setInterval(() => {
        GameGlobal.__towerPersistence.flush();
      }, 5000);
      _global.__towerStartup.mark("running");
      this.state = "running";
      console.log("[Loader] 6/6 ✓ 加载完成，游戏已启动");
      return engine;
    } catch (err) {
      _global.__towerStartup.mark("startup-failed", err && (err.stack || err.message) || err);
      if (this.state !== "disposed") this.state = "failed";
      this._stopLoadingTimer();
      // Keep the failure message visible if Godot has not taken the canvas.
      this._drawLoading();
      console.error("[Loader] ✗ 加载失败:", err);
      if (err && err.stack) console.error("[Loader] Stack:", err.stack);
      throw err;
    }
  }

  _assertNotDisposed() {
    if (this.state === "disposed") throw new Error("[Loader] Load was disposed");
  }

  _cleanupLoadingSurface() {
    if (this._loadingSurfaceCleaned) return;
    this._loadingSurfaceCleaned = true;
    this._ownsSurface = false;
    this._stopLoadingTimer();
    if (this._cancelImage) this._cancelImage();
    try {
      this.loadingCtx.clearRect(0, 0, this.loadingCanvas.width, this.loadingCanvas.height);
    } catch (_) {}
    try { this.cleanWebgl(); } catch (_) {}
    this.bgImage = null;
    this.loadingCanvas.width = 1;
    this.loadingCanvas.height = 1;
    // Restore the adapter's logical-pixel contract before Godot creates its
    // window, so gameplay size and touch coordinates retain their existing scale.
    _canvas.width = this._width;
    _canvas.height = this._height;
    this.screenCtx.viewport(0, 0, _canvas.width, _canvas.height);
  }

  _stopLoadingTimer() {
    if (this._loadingTimer !== null) _window.clearInterval(this._loadingTimer);
    this._loadingTimer = null;
  }

  dispose() {
    if (this.state === "disposed") return;
    if (this._syncTimer !== null) {
      _window.clearInterval(this._syncTimer);
      this._syncTimer = null;
    }
    if (this.engine && typeof this.engine.requestQuit === "function") {
      try { this.engine.requestQuit(); } catch (_) {}
    }
    if (_global.engine === this.engine) _safeSet(_global, "engine", null);
    this._cleanupLoadingSurface();
    this.state = "disposed";
  }
}

export default Loader;
