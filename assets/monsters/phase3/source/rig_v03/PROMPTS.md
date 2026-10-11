# 史莱姆新增退场来源

使用内置 imagegen，参考 rig_v02 的史莱姆分层组件。原始生成 exec-6077ed85-0259-4b33-aef1-f4307df76b99.png → slime_defeat_draft.png；透明清理 exec-8280cb49-2dcf-438c-894c-19bac7154db9.png → slime_defeat_cleanup.png。

## 生成提示

Use case: stylized-concept. Create ONE animation shape atlas for the GREEN SLIME's faceless outer membrane, matching the reference's emerald translucent gelatin, warm yellow rim highlight, small top curl. Exactly SIX sequential DEFEAT shapes in a strict3-column2-row layout. Ideally1536x1024, each cell512square, fully transparent background, NO ambient glow on background. No eyes/mouth because face and core are separate rig layers. Cell00 rounded normal dome left-biased;01 dome loses tension, slightly sags;02 shell buckles down and outward with a torn upward edge;10 mostly collapsed low puddle with two short wisps;11 very low shrinking puddle with few suspended small droplets;12 tiny last residue/droplets about one quarter initial volume. Keep every base contact at 88% of each cell height, horizontally centred, same painted light source and colour. Each entire silhouette including droplets stays at least32px away from cell edges; NO neighboring cell fragments, NO lines/text, NO shadows, NO ground. Genuine changing fluid topology, NOT six scaled copies. Identity/style reference only, omit reference's core sphere and face pieces. Death is magical harmless dissolution, no gore. Preserve real alpha transparency.

## 清理提示

Background-extraction cleanup of this SIX-cell green slime membrane defeat animation atlas. Keep every gelatin shape, its glossy rim, droplet, shape size, position and exact3x2 layout unchanged. Remove ALL broad green/yellow ambient haze from the empty space AROUND the gelatin and droplets. Outside the actual outlined gelatin and droplet silhouettes must be fully transparent alpha=0, including all cell gutters and edges. Do not erase the translucency INSIDE the slime. Keep clean antialiased edges. No background colour, checkerboard, black or white fill. Preserve1536x1024 arrangement and positions. This is a clean cutout sprite atlas; no glow, halo, light bloom or shadow outside the inked shapes.

