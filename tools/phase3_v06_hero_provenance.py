"""Record actual original image dimensions, alpha and source SHA; no pixel edits."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/hero/phase3/source/refine_v06'
calls=[
 ('right_components_draft.png','exec-7be72f38-b4b3-47d4-b708-7814704bddc6.png','PROMPTS.md#right_components', ['assets/art_concepts/hero_design_v01.png','assets/characters/hero/phase3/source/rig_v03/components_right.png']),
 ('components_right.png','exec-7cccb85c-99b7-4f9c-b435-bcbedb70a87e.png','PROMPTS.md#right_fix',['right_components_draft.png']),
 ('down_components_draft.png','exec-ef7ad6c0-a47f-488d-8a9b-a7f3ee49e600.png','prompt_down.txt',['assets/art_concepts/hero_design_v01.png','components_right.png']),
 ('down_components_edge_draft.png','exec-80c6b46c-4d35-415a-9b79-ce6eebd4ee58.png','prompt_down_fix.txt',['down_components_draft.png']),
 ('components_left.png','exec-954eb62e-21a6-47a9-bae4-1de2a4441f1a.png','prompt_left.txt',['assets/art_concepts/hero_design_v01.png','components_right.png']),
 ('up_components_edge_draft.png','exec-08fff137-c07c-404d-9d4a-23fa9dd40db2.png','prompt_up.txt',['assets/art_concepts/hero_design_v01.png','components_right.png']),
 ('components_down.png','exec-87dc12e6-d56a-445f-9821-2ab6892c5f5a.png','prompt_cape_edge_fix.txt',['down_components_edge_draft.png']),
 ('components_up.png','exec-e23ae8aa-a6dd-4bb3-9d56-ffca888c94a4.png','prompt_cape_edge_fix.txt',['up_components_edge_draft.png'])]
records=[]
for filename,original,prompt,refs in calls:
 image=Image.open(SOURCE/filename).convert('RGBA')
 records.append({'file':filename,'original_generated_filename':original,'actual_size':list(image.size),'sha256':hashlib.sha256((SOURCE/filename).read_bytes()).hexdigest(),'alpha_extrema':image.getchannel('A').getextrema(),'prompt':prompt,'reference_images':refs,'imagegen_mode':'built-in','transparent_background':True})
(SOURCE/'imagegen_provenance.json').write_text(json.dumps({'date':'2026-10-02','tool':'built-in image_gen','records':records},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Actual provenance:',len(records),'generated originals retained')
