const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const install = require('../tools/wechat/persistence.js');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'tower-wechat-test-'));
let failWrites = false;
let hide;
const disk = {
  accessSync: fs.accessSync,
  mkdirSync: p => fs.mkdirSync(p, {recursive: true}),
  readdirSync: fs.readdirSync,
  statSync: fs.statSync,
  readFileSync: p => { const b = fs.readFileSync(p); return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength); },
  writeFileSync: (p, data) => { if (failWrites) throw new Error('quota'); fs.writeFileSync(p, Buffer.from(data)); },
  renameSync: fs.renameSync,
};
function boot(name) {
  const ram = path.join(tmp, name);
  fs.mkdirSync(ram);
  const map = p => path.join(ram, p);
  const virtual = {
    mkdirTree: p => fs.mkdirSync(map(p), {recursive: true}),
    readdir: p => ['.', '..', ...fs.readdirSync(map(p))],
    stat: p => ({mode: fs.statSync(map(p)).isDirectory() ? 1 : 0}),
    isDir: mode => mode === 1,
    readFile: p => new Uint8Array(fs.readFileSync(map(p))),
    writeFile: (p, bytes) => fs.writeFileSync(map(p), bytes),
  };
  global.GameGlobal = {__adapter: {window: {}}};
  const module = {}, godotFS = {};
  const bridge = install(module, virtual, godotFS, {
    env: {USER_DATA_PATH: path.join(tmp, 'disk')},
    getFileSystemManager: () => disk, onHide: cb => {hide = cb;},
  });
  return {module, virtual, bridge, godotFS};
}
(async () => {
  const first = boot('first');
  await first.module.initFS(['/userfs']);
  first.virtual.mkdirTree('/userfs/game');
  const original = Buffer.from('{"种子":"9223372036854775807","楼层":3}');
  first.virtual.writeFile('/userfs/game/save.json', original);
  assert.equal(first.bridge.flush(), true);
  const second = boot('second');
  await second.module.initFS(['/userfs']);
  assert.deepEqual(Buffer.from(second.virtual.readFile('/userfs/game/save.json')), original);
  second.virtual.writeFile('/userfs/game/save.json', Buffer.from('updated'));
  failWrites = true;
  assert.equal(second.bridge.flush(), false);
  assert.match(second.bridge.error(), /quota/);
  assert.equal(fs.readFileSync(path.join(tmp, 'disk/towerrealm-v1/userfs/game/save.json'), 'utf8'), original.toString());
  failWrites = false;
  hide();
  const third = boot('third');
  await third.module.initFS(['/userfs']);
  assert.equal(Buffer.from(third.virtual.readFile('/userfs/game/save.json')).toString(), 'updated');
  assert.deepEqual(third.godotFS._mount_points, []);
  await assert.rejects(third.module.initFS(['/unexpected']), /Unexpected/);
  console.log('PASS: restore before main, Unicode/binary roundtrip, quota failure, retry, onHide flush, private paths');
})().catch(error => { console.error(error); process.exitCode = 1; });
