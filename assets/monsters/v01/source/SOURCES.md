# 来源

六张原图均由内置 image_gen 独立生成，原始文件无修改保留为本目录的 *_generated.png，实际尺寸均为 1254×1254 RGBA。生成时间：2026-09-29。原始工具输出位置见 generation_manifest.json，SHA-256 见 source_hashes.json。

人工查看并遵循的项目风格参考：
- assets/art_concepts/tower_character_map_v01.png
- assets/art_concepts/hero_design_v01.png

参考用于风格、配色、材质和比例判断，没有从概念图裁切怪物，没有以程序绘制角色。每个原始造型是新的独立生成，提示词见 PROMPTS.md。

最终 textures/*.png 由 scripts/previews/monster_art_v01/pack_assets.gd 做技术性透明画布规范化：定位 alpha>0.05 的主体边界、保留四个源像素余量、等比 Lanczos 缩小、放入 256×256 透明画布。原图空白区有极低 alpha 零星噪点，因此没有直接使用所有非零 alpha 的外接框；未在主体内改色、抠色或重绘，保留框内原生 alpha。

预览只读复用 assets/environment/tower_v01/textures/floor_0.png；该环境素材由地图线程提供，不属于本批怪物交付。缺少该文件时预览自动使用纯色测试格。
