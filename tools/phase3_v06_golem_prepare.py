"""Extract transparent attachment bounds; retain exact imagegen pixels."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/monsters/phase3/source/golem_v06'
image=Image.open(OUT/'golem_armor_attachments.png').convert('RGBA')
w,h=image.size
rects=[]
for col,row in [(0,0),(1,0),(0,1),(1,1)]:
    x,y=col*w//2,row*h//2
    region=image.crop((x,y,x+w//2,y+h//2))
    b=region.getchannel('A').getbbox()
    assert b and region.getchannel('A').getextrema()==(0,255), 'missing transparent art'
    rects.append([x+b[0],y+b[1],b[2]-b[0],b[3]-b[1]])
# Use measured painted-component rectangles; tiny alpha flecks cross cell edges.
# These are extraction bounds only; original atlas pixels remain untouched.
rects=[[90,35,527,550],[762,175,465,420],[72,649,578,558],[784,676,430,525]]
(OUT/'attachment_bounds.json').write_text(json.dumps(rects,indent=2),encoding='utf-8')
# Specialized native timed capture; shared capture/baker remain unchanged.
p=(ROOT/'tools/phase3_v05_native_capture.gd').read_text(encoding='utf-8')
p=p.replace('res://assets/monsters/phase3/source/parallel_v05/','res://assets/monsters/phase3/source/golem_v06/')
p=p.replace('res://build/verification/phase3/08-parallel/coordinator/native/','res://build/verification/phase3/09-refinement/golem/native/')
(ROOT/'tools/phase3_v06_golem_native_capture.gd').write_text(p,encoding='utf-8')
# Preserve the exact established public route, with independent evidence path.
host_path=ROOT/'tools/phase3_v06_golem_host_capture.gd'
if host_path.exists():
    host_text=host_path.read_text(encoding='utf-8')
    header=host_text.split('func _run_public_route()->void:')[0]
    decoded_override='\nfunc _decoded_bytes'+host_text.split('\nfunc _decoded_bytes',1)[1] if '\nfunc _decoded_bytes' in host_text else ''
    body=(ROOT/'tests/phase3_minotaur_host_capture.gd').read_text(encoding='utf-8').split('func _suite() -> void:\n',1)[1]
    body=body.replace('"enemy_action":pose.action,','"enemy_action":pose.action,"stone_armor_stage":pose.get("stone_armor_stage",0),')
    body=body.replace('core.store = store\n', 'await process_frame\n\tawait RenderingServer.frame_post_draw\n\troot.get_texture().get_image().save_png(capture_out+"save-failure.png")\n\tcore.store = store\n')
    body=body.replace('var boss_peak: int =', '_check(ui.board.enemy_map_art.frames.peak_cache_bytes <= 4*1024*1024,"map actual image data cache below 4MiB")\n\tvar boss_peak: int =')
    host_path.write_text(header+'func _run_public_route()->void:\n'+body+decoded_override,encoding='utf-8')
# Runtime pressure harness keeps its original UI overlap and texture RID checks.
runtime=(ROOT/'tests/phase3_v05_runtime_capture.gd').read_text(encoding='utf-8')
runtime=runtime.replace('08-parallel/coordinator/runtime/','09-refinement/golem/runtime/')
runtime=runtime.replace('08-parallel/coordinator/','08-parallel/golem_refine/')
runtime=runtime.replace('v05 runtime UI/cache:','v06 runtime UI/cache:')
(ROOT/'tools/phase3_v06_golem_runtime_capture.gd').write_text(runtime,encoding='utf-8')
production=(ROOT/'tests/phase3_v05_animation_test.gd').read_text(encoding='utf-8')
production=production.replace('res://build/verification/phase3/08-parallel/coordinator/','res://build/verification/phase3/09-refinement/golem/')
production=production.replace('08-parallel/coordinator/','08-parallel/golem_refine/')
(ROOT/'tools/phase3_v06_golem_production_test.gd').write_text(production,encoding='utf-8')
print(image.size,rects)
