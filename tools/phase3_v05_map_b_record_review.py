"""Record an explicit agent visual decision AFTER viewing. Not called by bake/check tools."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('entity',choices=['warlock','knight','berserker','warden','p3_ember_channeler','p3_vault_knight']);p.add_argument('--notes',required=True);p.add_argument('--visual-reviewed',action='store_true',required=True);args=p.parse_args()
folder=ROOT/'assets/monsters/phase3/source/parallel_v05/map'/args.entity
name=args.entity+'_map_draft_manifest.json';data=json.loads((folder/name).read_text(encoding='utf-8'));a=data['actions']['idle']
hashes=lambda paths:[hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in paths]
approval={'decision':'accepted','draft_manifest':name,'source_action':'idle','frame_slots':4,'pose_holds':{},'notes':args.notes,'frame_sha256':hashes(a['frames'])}
if a.get('effects_frames'):approval['effects_sha256']=hashes(a['effects_frames'])
review={'entity':args.entity,'date':'2026-10-02','review_method':'contact sheets plus native/browser playback; agent visual review','human_signoff':False,'new_imagegen_originals':2 if args.entity=='p3_ember_channeler' else 1,'actions':{'map_idle':approval},'visual_checks':['all four contact-sheet poses','browser original speed','browser 0.25 speed','paused next-frame 0 through 3','26px / 33px / 47px silhouettes','independent effect off if present'],'source_status':'draft','publication_owner':'coordinator','battle_actions_reviewed':[]}
(folder/(args.entity+'_publish_review.json')).write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
text=f'''# {args.entity} 独立地图 idle 视觉审阅

2026-10-02。内置 imagegen 新轻俯视正面组件原画，完整实际提示词见 PROMPTS.md。本目录源与烘焙清单仍为 draft，供统筹独立复查后发布。本组仅交付 map_idle，未制作或批准战斗动作。

4 帧 / 6 FPS / 循环；512 母版到 256 运行；脚底锚点 (128,224)；事件 {{}}；pose_holds {{}}，四个不同像素姿态。根节点固定，双脚接触固定，独立衣身呼吸、头部与双臂/披风轨道。肩/肘/腕、髋/膝/踝定位及武器握点保存在 JSON 和原生可编辑 Godot 场景。地图 idle 的完整手臂、完整腿为绘制层，肘/膝为编辑参考节点，本交付不包含行走或独立肘膝屈伸。

实际审阅：Godot 锁内烘焙并重载原生场景；全部四姿态联系图；本地浏览器原速、0.25 倍、暂停、逐帧 0–3；26/33/47px。决定：{args.notes}

身体和任何独立火焰效果分别保存，关闭效果后物理装备不消失。批准记录绑定当前身体/效果 PNG SHA256，烘焙、格式检查与此记录独立。human_signoff=false；accepted 仅为本 agent 对这些准确帧的视觉决定，真人动作自然度及目标平台验收仍未完成。

预览：{args.entity}_map_review.html。原速/四分之一速度透明 WebP、逐帧大图、小尺寸联系图、格式检查及隔离锁内 Godot 日志在 build/verification/phase3/08-parallel/map_b/。运行发布由统筹完成。
'''
(folder/'REVIEW.md').write_text(text,encoding='utf-8')
print('Explicit visual decision recorded:',args.entity,'map_idle',approval['frame_sha256'])
