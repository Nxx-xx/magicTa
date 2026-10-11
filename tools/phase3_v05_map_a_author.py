"""Author only map_a source rigs; packaging never approves or publishes art."""
import json
from pathlib import Path
from PIL import Image
from PIL import ImageFilter
from PIL import ImageDraw
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/monsters/phase3/source/parallel_v05/map'

def save(entity, data):
    out = BASE / entity
    out.mkdir(parents=True, exist_ok=True)
    (out / '.gdignore').touch()
    (out / f'{entity}_map_rig.json').write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')

def layer(name, parent, pivot, crop, image_pivot, scale, z, **extra):
    return dict(name=name, parent=parent, pivot=pivot, crop=crop,
                image_pivot=image_pivot, scale=scale, z=z, **extra)

def slime():
    image = Image.open(BASE/'slime/slime_map_components.png').convert('RGBA')
    cells = [(0,0,512,512),(512,0,1024,512),(1024,0,1536,512),
             (0,512,512,1024),(512,512,1024,1024),(1024,512,1536,1024)]
    boxes = []
    for x0,y0,x1,y1 in cells:
        bbox = image.crop((x0,y0,x1,y1)).getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
        l,t,r,b = bbox
        l,t,r,b = max(0,l-4),max(0,t-4),min(512,r+4),min(512,b+4)
        boxes.append([x0+l,y0+t,r-l,b-t])
    # Each organically painted membrane is registered by its base, no per-frame root shift.
    shapes = []
    for x,y,w,h in boxes[:4]:
        shapes.append(dict(source='slime_map_components.png',crop=[x,y,w,h],
                           canvas=[512,512],offset=[round((512-w)/2),448-h]))
    core = boxes[4]; face = boxes[5]
    poses = [dict(membrane=dict(shape=0)),
             dict(membrane=dict(shape=1),core=dict(p=[0,-3]),face=dict(p=[0,-2])),
             dict(membrane=dict(shape=0),core=dict(p=[1,1]),face=dict(p=[0,1])),
             dict(membrane=dict(shape=0),core=dict(p=[-1,2]),face=dict(p=[0,2]))]
    data = dict(version=1,status='draft',entity='slime_map',canvas=512,runtime_size=256,
                anchor=[256,448],rest_scale=1,source='slime_map_components.png',
                layers=[layer('membrane','root',[256,448],[0,0,512,512],[256,448],.82,0),
                        layer('core','membrane',[256,330],core,[core[2]/2,core[3]/2],.29,-1),
                        layer('face','membrane',[256,340],face,[face[2]/2,face[3]/2],.42,2)],
                shape_layers=dict(membrane=shapes),
                actions=dict(idle=dict(fps=6,loop=True,poses=poses,events={})),
                effect_layers=[],effect_actions=[],pose_holds={},
                camera='Independent elevated front orthographic map camera, 30 degrees',
                joints=dict(base_contact=[256,448],core_suspension=[256,330],face_attachment=[256,340]),
                acceptance='Draft requires contact, playback, slow/step and 26/33/47px visual review')
    save('slime',data)
    print('slime: 3 paint layers, 4 frame slots; independent painted membrane shapes')

def source_bounds(entity, regions, filename=None):
    image=Image.open(BASE/entity/(filename or f'{entity}_map_components.png')).convert('RGBA')
    boxes={}
    for name,region in regions.items():
        x0,y0,x1,y1=region
        x1=min(x1,image.width);y1=min(y1,image.height)
        piece=image.crop((x0,y0,x1,y1))
        alpha=piece.getchannel('A'); w,h=piece.size
        # Isolate the largest existing alpha island, removing neighboring atlas parts.
        # No paint is generated or recolored: retained source RGBA values are untouched.
        raw=alpha.tobytes();seen=bytearray(w*h);best=[]
        for start,a in enumerate(raw):
            if a<64 or seen[start]:continue
            queue=deque([start]);seen[start]=1;island=[]
            while queue:
                at=queue.popleft();island.append(at);px=at%w;py=at//w
                for nx,ny in ((px-1,py),(px+1,py),(px,py-1),(px,py+1)):
                    if nx<0 or nx>=w or ny<0 or ny>=h:continue
                    nxt=ny*w+nx
                    if not seen[nxt] and raw[nxt]>=64:seen[nxt]=1;queue.append(nxt)
            if len(island)>len(best):best=island
        mask_bytes=bytearray(w*h)
        for at in best:mask_bytes[at]=255
        mask=Image.frombytes('L',(w,h),bytes(mask_bytes)).filter(ImageFilter.MaxFilter(7))
        if name in ('feet','effect'):
            mask=Image.new('L',(w,h),255)
        clean=Image.new('RGBA',(w,h));clean.paste(piece,(0,0),mask)
        bbox=clean.getchannel('A').getbbox()
        clean=clean.crop(bbox)
        parts=BASE/entity/f'{entity}_map_parts';parts.mkdir(exist_ok=True)
        clean.save(parts/f'{name}.png')
        boxes[name]=[0,0,clean.width,clean.height]
    return boxes

def humanoid(entity):
    if entity=='skeleton':
        regions=dict(head=[38,0,370,404],torso=[405,0,805,391],pelvis=[817,15,1210,389],
                     left_arm=[70,402,370,803],right_arm=[875,402,1205,803],weapon=[492,396,747,808],
                     left_leg=[82,805,365,1260],right_leg=[878,805,1205,1270],shield=[402,810,804,1260])
        b=source_bounds(entity,regions)
        layers=[layer('left_leg','root',[227,326],b['left_leg'],[b['left_leg'][2]*.55,10],.30,-4),
                layer('right_leg','root',[291,326],b['right_leg'],[b['right_leg'][2]*.45,10],.30,-3),
                layer('pelvis','root',[256,316],b['pelvis'],[b['pelvis'][2]/2,b['pelvis'][3]*.4],.30,-1),
                layer('torso','root',[256,294],b['torso'],[b['torso'][2]/2,b['torso'][3]-10],.44,0),
                layer('head','torso',[256,168],b['head'],[b['head'][2]/2,b['head'][3]-6],.40,3),
                layer('left_arm','torso',[184,173],b['left_arm'],[b['left_arm'][2]*.67,18],.36,4),
                layer('right_arm','torso',[328,173],b['right_arm'],[b['right_arm'][2]*.33,18],.36,1),
                dict(name='sword_grip',parent='left_arm',pivot=[193,280],joint_only=True,z=2),
                dict(name='shield_grip',parent='right_arm',pivot=[299,291],joint_only=True,z=2),
                layer('sword','sword_grip',[193,280],b['weapon'],[b['weapon'][2]/2,b['weapon'][3]*.85],.40,2),
                layer('shield','shield_grip',[310,307],b['shield'],[b['shield'][2]/2,b['shield'][3]/2],.28,5)]
        poses=[{},dict(head=dict(r=-.65),torso=dict(p=[0,-1]),left_arm=dict(r=.7),right_arm=dict(r=-.45)),
               dict(head=dict(r=-1.1),torso=dict(p=[0,-2]),left_arm=dict(r=1.1),right_arm=dict(r=-.7)),
               dict(head=dict(r=.35),left_arm=dict(r=-.45),right_arm=dict(r=.3))]
    else:
        shield_variant=entity=='p3_shield_sentinel'
        regions=dict(head=[40,65,315,366],torso=[320,0,870,481],pelvis=[872,65,1247,400],
                     left_arm=[20,390,359,850],right_arm=[865,390,1247,851],core=[485,515,735,760],
                     left_leg=[90,838,388,1255],right_leg=[850,839,1170,1255],effect=[480,865,782,1163])
        if shield_variant:
            regions=dict(head=[40,30,316,310],torso=[319,0,870,390],pelvis=[865,65,1214,405],
                         left_arm=[42,371,359,851],right_arm=[857,389,1214,851],shield=[380,389,831,975],
                         left_leg=[56,851,375,1295],right_leg=[843,855,1178,1295],effect=[520,1000,670,1200])
        b=source_bounds(entity,regions)
        layers=[layer('left_leg','root',[218,332],b['left_leg'],[b['left_leg'][2]*.58,8],.32,-5),
                layer('right_leg','root',[294,332],b['right_leg'],[b['right_leg'][2]*.42,8],.32,-4),
                layer('pelvis','root',[256,315],b['pelvis'],[b['pelvis'][2]/2,b['pelvis'][3]/2],.34,-2),
                layer('torso','root',[256,298],b['torso'],[b['torso'][2]/2,b['torso'][3]-12],.49,0),
                layer('head','torso',[256,160],b['head'],[b['head'][2]/2,b['head'][3]-4],.45,3),
                layer('left_arm','torso',[152,164],b['left_arm'],[b['left_arm'][2]*.62,32],.40,-1),
                layer('right_arm','torso',[350,164],b['right_arm'],[b['right_arm'][2]*.28,32],.40,1)]
        if shield_variant:
            layers += [dict(name='shield_grip',parent='right_arm',pivot=[352,296],joint_only=True,z=2),
                       layer('shield','shield_grip',[352,296],b['shield'],[b['shield'][2]*.72,b['shield'][3]*.49],.36,4),
                       layer('amber_glint','shield',[314,269],b['effect'],[b['effect'][2]/2,b['effect'][3]/2],.20,5)]
        else:
            layers += [layer('core','torso',[256,214],b['core'],[b['core'][2]/2,b['core'][3]/2],.22,2),
                       layer('teal_grooves','torso',[256,211],b['effect'],[b['effect'][2]/2,b['effect'][3]/2],.24,3)]
        effect_name='amber_glint' if shield_variant else 'teal_grooves'
        poses=[{effect_name:dict(a=.12)},
               dict(head=dict(r=-.45),left_arm=dict(r=.55),right_arm=dict(r=-.4),**{effect_name:dict(a=.24)}),
               dict(head=dict(r=-.8),left_arm=dict(r=.9),right_arm=dict(r=-.7),**{effect_name:dict(a=.32)}),
               dict(head=dict(r=.25),left_arm=dict(r=-.35),right_arm=dict(r=.25),**{effect_name:dict(a=.18)})]
    part_names={'sword':'weapon','amber_glint':'effect','teal_grooves':'effect'}
    for item in layers:
        if not item.get('joint_only'):
            item['source']=f'{entity}_map_parts/{part_names.get(item["name"],item["name"])}.png'
        if item['name'] in ('left_leg','right_leg'):
            item['pivot'][1]=448-(item['crop'][3]-item['image_pivot'][1])*item['scale']
        if entity=='p3_shield_sentinel' and item['name']=='head':item['pivot'][1]=182
    for side in ('left','right'):
        arm=next(x for x in layers if x['name']==f'{side}_arm')
        elbow=([140,228] if side=='left' else [366,227]) if entity=='skeleton' else ([140,235] if side=='left' else [375,232])
        layers.append(dict(name=f'{side}_elbow',parent=f'{side}_arm',pivot=elbow,joint_only=True,z=0))
        leg=next(x for x in layers if x['name']==f'{side}_leg')
        knee=[leg['pivot'][0],leg['pivot'][1]+60]
        layers.append(dict(name=f'{side}_knee',parent=f'{side}_leg',pivot=knee,joint_only=True,z=0))
        layers.append(dict(name=f'{side}_ground_contact',parent='root',pivot=[leg['pivot'][0],448],joint_only=True,z=0))
    data=dict(version=1,status='draft',entity=f'{entity}_map',canvas=512,runtime_size=256,
              anchor=[256,448],rest_scale=1,source=f'{entity}_map_components.png',layers=layers,
              actions=dict(idle=dict(fps=6,loop=True,poses=poses,events={})),pose_holds={},
              camera='Independent elevated front orthographic map camera, 30 degrees',
              joints=dict(neck=[256,168],left_shoulder=[184,173] if entity=='skeleton' else [152,164],
                          right_shoulder=[328,173] if entity=='skeleton' else [350,164],
                          left_elbow=[173,239],right_elbow=[342,239],
                          left_hip=layers[0]['pivot'],right_hip=layers[1]['pivot'],ground_anchor=[256,448]),
              acceptance='Draft requires separate visual inspection and exact hash approval')
    if entity!='skeleton':
        data.update(effect_layers=[effect_name],effect_actions=['idle'])
    else:data.update(effect_layers=[],effect_actions=[])
    data['joints']={item['name']:item['pivot'] for item in layers if item.get('joint_only') or item['name'] in ('head','left_arm','right_arm','left_leg','right_leg')}
    data['joints']['ground_anchor']=[256,448]
    save(entity,data)
    print(f'{entity}: {len(layers)} native bones, four idle frames')

def bat():
    entity='bat'
    b=source_bounds(entity,dict(body=[550,0,984,450],left_wing=[0,0,530,427],
                               right_wing=[1010,0,1536,427],feet=[620,500,920,686]))
    # Split the separately painted complete wing along its main spar with overlap.
    # Both pieces retain only existing imagegen pixels, no synthesized paint.
    parts=BASE/entity/'bat_map_parts'
    layers=[]
    for side,shoulder in [('left',[223,220]),('right',[289,220])]:
        image=Image.open(parts/f'{side}_wing.png').convert('RGBA');w,h=image.size
        elbow=(round(w*.54),round(h*.04)) if side=='left' else (round(w*.46),round(h*.04))
        distal=(round(w*.32),round(h*.85)) if side=='left' else (round(w*.68),round(h*.85))
        for kind in ['inner','tip']:
            mask=Image.new('L',(w,h));draw=ImageDraw.Draw(mask)
            ex,ey=elbow;dx,dy=distal
            if (side=='left' and kind=='tip') or (side=='right' and kind=='inner'):
                poly=[(0,0),(ex+4,0),(dx+4,h),(0,h)]
            else:poly=[(ex-4,0),(w,0),(w,h),(dx-4,h)]
            draw.polygon(poly,fill=255)
            sliced=Image.new('RGBA',(w,h));sliced.paste(image,(0,0),mask)
            sliced.save(parts/f'{side}_{kind}.png')
        ip=[w-22,round(h*.50)] if side=='left' else [22,round(h*.50)]
        scale=.32
        layers.append(layer(f'{side}_wing','body',shoulder,[0,0,w,h],ip,scale,-2,
                            source=f'bat_map_parts/{side}_inner.png'))
        tip_pivot=[shoulder[0]+(elbow[0]-ip[0])*scale,shoulder[1]+(elbow[1]-ip[1])*scale]
        layers.append(layer(f'{side}_wingtip',f'{side}_wing',tip_pivot,[0,0,w,h],list(elbow),scale,-3,
                            source=f'bat_map_parts/{side}_tip.png'))
    body=b['body'];feet=b['feet']
    layers += [layer('body','root',[256,280],body,[body[2]/2,body[3]*.66],.43,2,source='bat_map_parts/body.png'),
               layer('feet','body',[256,334],feet,[feet[2]/2,0],.30,1,source='bat_map_parts/feet.png')]
    poses=[]
    for height,wing,tip in [(0,-6,-5),(-3,18,12),(-5,5,2),(-1,-19,-12)]:
        poses.append(dict(body=dict(p=[0,height]),left_wing=dict(r=wing),right_wing=dict(r=-wing),
                          left_wingtip=dict(r=tip),right_wingtip=dict(r=-tip),feet=dict(r=wing*.1)))
    save(entity,dict(version=1,status='draft',entity='bat_map',canvas=512,runtime_size=256,
                     anchor=[256,448],rest_scale=1,source='bat_map_components.png',layers=layers,
                     actions=dict(idle=dict(fps=8,loop=True,poses=poses,events={})),
                     effect_actions=[],effect_layers=[],pose_holds={},
                     joints=dict(left_shoulder=[223,220],right_shoulder=[289,220],
                                 left_elbow=layers[1]['pivot'],right_elbow=layers[3]['pivot'],
                                 toe_attachment=[256,334],ground_projection=[256,448]),
                     camera='Independent elevated front orthographic map camera, 30 degrees',
                     acceptance='Inspect wing joints, all four poses, original/quarter and small sizes'))
    print('bat: body/feet and independently articulated left/right wings and tips, 4/8 idle')

if __name__ == '__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('entity',nargs='?',default='slime')
    entity=parser.parse_args().entity
    if entity=='slime':slime()
    elif entity=='bat':bat()
    else:humanoid(entity)
