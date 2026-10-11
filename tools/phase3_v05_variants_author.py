"""Author variant equipment bindings/actions over readonly base rig snapshots.
No original painting, production writes, or visual approval performed here.
"""
import argparse, copy, hashlib, json, math, shutil
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
VAR=ROOT/'assets/monsters/phase3/source/parallel_v05/variants'
BASE=VAR.parent/'battle'
IDS={'p3_shield_sentinel':'sentinel','p3_ember_channeler':'warlock','p3_vault_knight':'knight'}
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rot(p,a):
 a=math.radians(a);return [p[0]*math.cos(a)-p[1]*math.sin(a),p[0]*math.sin(a)+p[1]*math.cos(a)]
def add(a,b):return [a[0]+b[0],a[1]+b[1]]
def sub(a,b):return [a[0]-b[0],a[1]-b[1]]
def world(name,pose,layers):
 if name=='root':return [0,0],0
 l=layers[name];pp,pr=world(l['parent'],pose,layers);origin=[0,0] if l['parent']=='root' else layers[l['parent']]['pivot']
 return add(pp,rot(add(sub(l['pivot'],origin),pose.get(name,{}).get('p',[0,0])),pr)),pr+pose.get(name,{}).get('r',0)
def legs(p,layers,dx,dy):
 for side in ['near','far']:
  t=side+'_thigh';s=side+'_shin';f=side+('_foot' if side+'_foot' in layers else '_ankle')
  hp=layers[t]['pivot'];kp=layers[s]['pivot'];ap=layers[f]['pivot'];h=add(hp,[dx,dy]);length1=math.dist(hp,kp);length2=math.dist(kp,ap);dist=math.dist(h,ap);d=min(dist,length1+length2-.001)
  along=(length1**2-length2**2+d*d)/(2*d);height=math.sqrt(max(0,length1**2-along**2));u=[(ap[0]-h[0])/dist,(ap[1]-h[1])/dist];k=[h[0]+u[0]*along-u[1]*height,h[1]+u[1]*along+u[0]*height]
  angle=lambda a,b:math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
  r1=angle(h,k)-angle(hp,kp);r2=angle(k,ap)-angle(kp,ap)-r1
  p[t]={'p':[dx,dy],'r':r1};p[s]={'r':r2}
  if side+'_foot' in layers:p[f]={'r':-r1-r2}
def cells(image,grid):
 w,h=image.size;out=[]
 for y in range(grid[1]):
  for x in range(grid[0]):
   box=(x*w//grid[0],y*h//grid[1],(x+1)*w//grid[0],(y+1)*h//grid[1]);b=image.crop(box).getchannel('A').getbbox();out.append([b[0]+box[0],b[1]+box[1],b[2]-b[0],b[3]-b[1]])
 return out
def shield_arm(p,ls,target):
 # Two-bone IK moves the hand and shield together; equipment never slides off grip.
 sh,sr=world('far_upper_arm',p,ls);tp,tr=world('torso',p,ls)
 hp=ls['far_upper_arm']['pivot'];kp=ls['far_forearm']['pivot'];gp=ls['shield_grip']['pivot']
 l1=math.dist(hp,kp);l2=math.dist(kp,gp);dist=math.dist(sh,target);d=min(dist,l1+l2-.001)
 along=(l1*l1-l2*l2+d*d)/(2*d);height=math.sqrt(max(0,l1*l1-along*along));u=[(target[0]-sh[0])/dist,(target[1]-sh[1])/dist]
 k=[sh[0]+u[0]*along+u[1]*height,sh[1]+u[1]*along-u[0]*height]
 angle=lambda a,b:math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
 r1=angle(sh,k)-angle(hp,kp)-tr;r2=angle(k,target)-angle(kp,gp)-tr-r1
 p['far_upper_arm']={'r':r1};p['far_forearm']={'r':r2};p['shield']={'r':-tr-r1-r2}
def author(id):
 e=IDS[id];out=VAR/id;source=BASE/e/(e+'_rig.json');d=json.loads(source.read_text(encoding='utf8'));d=copy.deepcopy(d)
 provenance={'base_entity':e,'base_rig':str(source.relative_to(ROOT)).replace('\\','/'),'base_rig_sha256':sha(source),'originals':{}}
 files={d['source']}|{l['source'] for l in d['layers'] if 'source' in l}
 for name in files:
  src=BASE/e/name;dest=out/('base_'+Path(name).name);shutil.copy2(src,dest);provenance['originals'][name]=sha(src)
 d['source']='base_'+Path(d['source']).name
 for l in d['layers']:
  if 'source' in l:l['source']='base_'+Path(l['source']).name
 d['entity']=id;d['status']='draft';d['base_provenance']=provenance;d['scene']='battle';d['camera']='three-quarter facing left';d['acceptance']='Draft, explicit visual review required; human_signoff=false'
 acc=id+'_accessories.png';im=Image.open(out/acc).convert('RGBA');boxes=cells(im,(3,1) if e=='sentinel' else (2,2));ls={l['name']:l for l in d['layers']}
 if e in ['sentinel','warlock']:
  # Generated objects do not obey nominal thirds; crop whole transparent components.
  boxes=[]
  regions=([(0,0,700,887),(700,0,1380,887),(1380,0,1773,887)] if e=='sentinel' else [(0,0,635,710),(635,0,1254,660),(0,720,650,1254),(660,660,1254,1254)])
  for box in regions:
   b=im.crop(box).getchannel('A').getbbox();boxes.append([b[0]+box[0],b[1]+box[1],b[2]-b[0],b[3]-b[1]])
 def accessory(name,parent,pivot,index,width,z,ip=(.5,.5)):
  b=boxes[index];l=dict(name=name,parent=parent,pivot=pivot,crop=b,image_pivot=[b[2]*ip[0],b[3]*ip[1]],scale=width/b[2],z=z,source=acc);d['layers'].append(l);ls[name]=l;return l
 if e in ['sentinel','knight']:
  old=ls['shield'];b=boxes[0];old.update(source=acc,crop=b,image_pivot=[b[2]*.5,b[3]*.46],scale=(125 if e=='sentinel' else 98)/b[2])
 if e=='sentinel':
  accessory('bastion_shoulder','torso',[328,199],1,77,6,ip=(.5,.35))
  accessory('guard_rune','shield',[321,327],2,42,9)
 elif e=='warlock':
  accessory('trident_head','staff',[332,150],0,89,6,ip=(.5,.95))
  accessory('furnace_ring','torso',[344,221],1,135,-4)
  accessory('furnace_collar','torso',[296,238],2,76,5)
  accessory('charge_flame','cast_grip',[190,327],3,67,8,ip=(.5,.8))
 else:
  accessory('key_crown','head',[278,114],1,77,6,ip=(.5,.95))
  accessory('lock_shoulder','torso',[326,193],2,67,6,ip=(.5,.3))
  accessory('threat_glint','sword',[186,232],3,72,9)
 effect={'sentinel':'guard_rune','warlock':'charge_flame','knight':'threat_glint'}[e];d['effect_layers']=d.get('effect_layers',[])+[effect];d['effect_actions']=list(d['actions'])
 for action,a in d['actions'].items():
  for i,p in enumerate(a['poses']):p[effect]={'a':0}
 action={'sentinel':'guard','warlock':'charge','knight':'threat'}[e];poses=[]
 for i in range(4):
  p=copy.deepcopy(d['actions']['idle']['poses'][0])
  if e=='sentinel':
   dx,dy=[(0,2),(-4,8),(2,11),(0,3)][i];p['torso']={'p':[dx,dy],'r':[0,-3,4,0][i]};p['head']={'r':[0,3,-2,0][i]};p['near_upper_arm']={'r':[0,8,-4,2][i]};p[effect]={'a':[0,.35,.9,.1][i]};legs(p,ls,dx,dy)
   shield_arm(p,ls,[[321,329],[262,277],[271,288],[302,320]][i])
  elif e=='warlock':
   dy=[2,8,4,1][i];p['torso']={'p':[0,dy],'r':[0,3,-2,0][i]};p['hood']={'r':[0,-5,-8,-1][i]};p['near_upper_arm']={'r':[8,20,28,10][i]};p['near_forearm']={'r':[10,25,32,15][i]};p['far_upper_arm']={'r':[0,-8,-12,-3][i]};p['far_forearm']={'r':[0,5,8,2][i]};grip,a=world('staff_grip',p,ls);p['staff']={'p':sub(grip,ls['staff']['pivot']),'r':a};p['furnace_ring']={'r':[0,-8,-15,-4][i]};p[effect]={'a':[.25,.6,1,.4][i],'r':[0,-7,10,3][i]};p['flame']['a']=0
  else:
   dx,dy=[(0,2),(3,8),(-3,6),(0,1)][i];p['torso']={'p':[dx,dy],'r':[0,4,-5,-1][i]};p['head']={'r':[0,-4,-6,-2][i]};p['near_upper_arm']={'r':[-15,-48,-66,-24][i]};p['near_forearm']={'r':[-8,-20,-15,-7][i]};p['sword']={'r':[-20,24,55,-6][i]};p['far_upper_arm']={'r':[0,5,10,3][i]};p['cape_upper']={'r':[0,7,-8,-2][i]};p['cape_lower']={'r':[0,5,-5,-1][i]};p[effect]={'a':[0,.25,.7,.1][i]};legs(p,ls,dx,dy)
  poses.append(p)
 d['actions'][action]={'fps':12 if e=='sentinel' else 8,'loop':False,'events':{ {'sentinel':'guard_contact','warlock':'charge_peak','knight':'threat_peak'}[e]:2},'poses':poses};d['effect_actions'].append(action)
 # Accessories inherit real limb/hood transforms during base actions including collapse.
 d['attachment_registration']={'image_size':list(im.size),'alpha_bbox_crops':boxes,'non_effect_identity_layers':[l['name'] for l in d['layers'] if l.get('source')==acc and l['name']!=effect]}
 write(out/(id+'_rig.json'),d);write(out/'base_provenance.json',provenance)
 print(id,len(d['layers']),'layers;',sum(len(a['poses']) for a in d['actions'].values()),'battle slots; draft only')
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--entity',choices=IDS,required=True);args=parser.parse_args();author(args.entity)
