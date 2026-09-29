"""Download the pinned Godot 4.7.2 Android test-build dependencies into build/."""
import concurrent.futures, hashlib, io, json, pathlib, shutil, struct, urllib.request, zipfile, zlib
ROOT=pathlib.Path(__file__).resolve().parents[1] / "build/android/toolchain"
ROOT.mkdir(parents=True, exist_ok=True)
(ROOT.parents[1] / ".gdignore").touch()

def download(name,url,size,sha1=None,first=0):
 path=ROOT/name
 if path.exists() and path.stat().st_size==size:
  print(name,'cached',flush=True)
 else:
  part=path.with_suffix(path.suffix+'.part')
  chunk=2*1024*1024
  segments=ROOT/(name+'.segments')
  segments.mkdir(exist_ok=True)
  if part.exists():
   with part.open('rb') as previous:
    for start in range(0,part.stat().st_size,chunk):
     data=previous.read(chunk)
     if len(data)==min(chunk,size-start): (segments/str(start)).write_bytes(data)
  def fetch(start):
   end=min(start+chunk,size)-1
   segment=segments/str(start)
   if segment.exists() and segment.stat().st_size==end-start+1: return segment
   for attempt in range(5):
    try:
     req=urllib.request.Request(url,headers={'Range':f'bytes={first+start}-{first+end}'})
     with urllib.request.urlopen(req,timeout=45) as f:
      data=f.read()
      if f.status!=206 or len(data)!=end-start+1: raise RuntimeError('Unexpected response range')
     segment.write_bytes(data)
     return segment
    except Exception:
     if attempt==4: raise
  with concurrent.futures.ThreadPoolExecutor(max_workers=6) as workers:
   futures=[workers.submit(fetch,start) for start in range(0,size,chunk)]
   for index,future in enumerate(concurrent.futures.as_completed(futures),1):
    future.result()
    if index%8==0 or index==len(futures): print(name,f'{index}/{len(futures)} chunks',flush=True)
  with part.open('wb') as out:
   for start in range(0,size,chunk): out.write((segments/str(start)).read_bytes())
  part.replace(path)
 if sha1 and hashlib.sha1(path.read_bytes()).hexdigest()!=sha1: raise RuntimeError('Checksum mismatch: '+name)
 return path

def extract(path,dest):
 dest.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(path) as z:
  for n in z.namelist():
   if not (dest/n).resolve().is_relative_to(dest.resolve()): raise RuntimeError('Unsafe zip path')
  z.extractall(dest)

def templates():
 p=download('android-template-entry.bin','https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz',125834961)
 with p.open('rb') as f:
  header=f.read(30)
  fields=struct.unpack('<4s5H3I2H',header)
  f.read(fields[-2]+fields[-1])
  data=zlib.decompress(f.read(125834876),-15)
 if len(data)!=127260725: raise RuntimeError('Template size mismatch')
 target=ROOT/'templates/android_debug.apk'
 target.parent.mkdir(exist_ok=True)
 target.write_bytes(data)
 with zipfile.ZipFile(target) as z:
  if z.testzip(): raise RuntimeError('Template corrupt')
 print('Android template ready',flush=True)

def jdk():
 url='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip'
 p=download('jdk.zip',url,190817615)
 with urllib.request.urlopen(url+'.sha256.txt',timeout=30) as f: expected=f.read().decode().split()[0]
 if hashlib.sha256(p.read_bytes()).hexdigest()!=expected: raise RuntimeError('JDK checksum mismatch')
 extract(p,ROOT/'java')
 print('JDK ready',flush=True)

def sdk():
 p=download('build-tools.zip','https://dl.google.com/android/repository/build-tools_r35.0.1_windows.zip',59876477,'1cbfa5564b62504a1111352edda35914cf723a20')
 extract(p,ROOT/'sdk/build-tools')
 parent=ROOT/'sdk/build-tools'
 if not (parent/'35.0.1').exists(): next(d for d in parent.iterdir() if d.is_dir()).rename(parent/'35.0.1')
 p=download('platform-tools.zip','https://dl.google.com/android/repository/platform-tools_r37.0.1-win.zip',8044989,'e03e78b1d80b396f1c3358e31251cb31740e1110')
 extract(p,ROOT/'sdk')
 print('SDK tools ready',flush=True)

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 futures=[pool.submit(job) for job in (templates,jdk,sdk)]
 for f in concurrent.futures.as_completed(futures): f.result()
print('All APK dependencies ready',flush=True)
