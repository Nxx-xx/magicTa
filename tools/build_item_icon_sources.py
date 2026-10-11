"""Author original, editable SVG icons in the established phase3 visual language.

No gameplay data is rewritten. Raster export uses tools/bake_item_icons.gd.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/items/unique/source'
OUT.mkdir(parents=True, exist_ok=True)
DEFS = '''<defs>
<linearGradient id="steel" x2=".8" y2="1"><stop stop-color="#e2f1ed"/><stop offset=".48" stop-color="#91b1b8"/><stop offset="1" stop-color="#416478"/></linearGradient>
<linearGradient id="gold" x2=".7" y2="1"><stop stop-color="#fff0bd"/><stop offset=".5" stop-color="#dfb76f"/><stop offset="1" stop-color="#9b633c"/></linearGradient>
<linearGradient id="leather" x2=".8" y2="1"><stop stop-color="#c59364"/><stop offset="1" stop-color="#634333"/></linearGradient>
<linearGradient id="jade" x2=".7" y2="1"><stop stop-color="#bbf1d6"/><stop offset="1" stop-color="#398886"/></linearGradient>
<linearGradient id="onyx" x2=".8" y2="1"><stop stop-color="#8e91ab"/><stop offset=".45" stop-color="#46516e"/><stop offset="1" stop-color="#272d45"/></linearGradient>
<linearGradient id="red" x2=".8" y2="1"><stop stop-color="#ffb49a"/><stop offset=".5" stop-color="#bd5260"/><stop offset="1" stop-color="#6a354e"/></linearGradient>
</defs>'''

def p(d, fill, extra=''):
    return f'<path d="{d}" fill="{fill}" {extra}/>'

def line(d, color='#f3d49a', width=6):
    return p(d, 'none', f'stroke="{color}" stroke-width="{width}"')

def circle(x, y, r, fill, extra=''):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" {extra}/>'

S, G, L, J, O, R = [f'url(#{n})' for n in ['steel','gold','leather','jade','onyx','red']]
icons = {}
# Four sword silhouettes: plain straight, swept single edge, hooked blood blade,
# and broad ceremonial gold blade. They remain different in monochrome.
icons['iron_sword'] = '<g transform="rotate(32 128 128)">' + p('M128 31L143 56V150H113V56Z', S) + line('M128 47V140','#eff9ed',4) + p('M91 146H165L160 162H96Z', G) + p('M117 164H139V204H117Z', L) + line('M118 177H137M118 190H137','#e1b780',4) + circle(128,213,10,G) + '</g>'
icons['steel_blade'] = p('M78 170Q159 126 182 34Q207 113 102 187Z', S) + line('M104 167Q168 124 180 75','#eff9ed',5) + p('M70 154L113 186L100 203L58 170Z',G) + p('M75 178L92 191L64 224L46 210Z',O) + line('M64 193L80 205','#9ebfc3',5)
icons['hunter_bow'] = line('M83 34L181 128L83 222','#e9e1bd',5) + p('M81 34Q164 48 187 128Q164 208 81 222L89 207Q152 186 168 128Q152 70 89 49Z',L) + line('M94 51Q158 76 174 128Q158 181 94 206','#e9c483',4) + line('M172 114L178 140','#384657',14) + line('M42 128H201','#e5c080',6) + p('M220 128L197 114V142Z',S) + p('M58 127L39 112V126L49 133L39 143V151L62 134Z',J)
icons['iron_armor'] = p('M90 43L63 55L39 88L68 109L76 205Q128 225 180 205L188 109L217 88L193 55L166 43Q163 78 128 79Q93 78 90 43Z',S) + p('M93 47Q95 73 128 74Q161 73 163 47L151 42Q128 57 105 42Z',O) + line('M82 97L91 180Q128 193 165 180L174 97','#dbe7d9',5) + line('M128 87V185','#54778b',7) + p('M77 184Q128 202 179 184V204Q128 223 77 204Z',L) + p('M115 190H140V210H115Z',G)
icons['tower_shield'] = p('M58 39H198V161L128 222L58 161Z',S) + p('M73 53H183V151L128 201L73 151Z',O) + p('M117 55H139V104H179V124H139V191L128 203L117 191V124H77V104H117Z',G) + circle(128,114,13,S) + ''.join(circle(x,y,4,'#f4d89a','stroke="none"') for x,y in [(64,47),(192,47),(65,155),(191,155)])
icons['heart_pendant'] = line('M66 39Q66 90 118 120M190 39Q190 90 138 120','#e5c385',9) + circle(128,120,13,G) + p('M128 157C88 112 52 150 74 179L128 220L182 179C204 150 168 112 128 157Z',G) + p('M128 170C98 137 76 155 91 176L128 202L165 176C180 155 158 137 128 170Z',R) + line('M95 158L103 152','#ffe9d2',6)
icons['duelist_gloves'] = '<g transform="rotate(-12 128 128)">' + p('M63 165L51 110Q51 91 65 98L81 126V60Q83 43 96 53L100 115V43Q110 30 119 44L121 114V52Q134 40 142 55L143 119V77Q156 68 162 84L159 144L137 178Z',L) + line('M93 138L137 135','#edc394',5) + p('M64 161L143 167L148 211L71 217Z',O) + line('M72 179L139 183','#e4c087',8) + p('M101 172H124V194H101Z',G) + '</g>' + p('M160 130L184 100Q202 95 205 111L200 176L182 215L153 203L158 165Z',L) + line('M167 189L183 196','#e8c189',7)
icons['knight_plate'] = p('M96 44H160L178 65L210 65L223 110L189 119L179 162L190 210H66L77 162L67 119L33 110L46 65H78Z',S) + p('M100 43L111 74H145L156 43Z',O) + p('M83 80L128 98L173 80L165 151L128 178L91 151Z',S) + line('M128 98V167','#f7e3b2',7) + p('M89 167L128 184L167 167L174 183L128 204L82 184Z',O) + line('M48 86L73 91M183 91L207 86M80 205H176','#e4bf7d',7)
icons['vital_crown'] = p('M41 84L85 119L96 54L128 101L162 54L174 119L215 84L193 197Q128 216 63 197Z',G) + p('M68 168Q128 186 188 168L185 190Q128 204 71 190Z',O) + p('M128 109L150 144L128 177L106 144Z',J) + circle(82,151,8,J) + circle(176,151,8,J) + line('M128 119L118 141','#e8ffde',5)
icons['dawn_spear'] = line('M53 217L167 95','#27364a',16) + line('M53 217L167 95','#d6ac71',8) + p('M151 111L158 63L214 34L198 94Z',S) + p('M161 101L207 42L184 100Z',G) + p('M146 101L176 127L164 139L135 115Z',G) + p('M151 128Q149 164 122 167L132 143L112 142L139 121Z',R)
icons['obsidian_mail'] = p('M93 42L128 60L163 42L180 68L212 51L219 112L183 119L176 199L151 218L128 200L104 218L79 199L72 119L37 112L44 51L76 68Z',O) + p('M86 82L128 101L171 82L162 136L128 159L94 136Z',O) + p('M128 103L145 124L128 146L111 124Z',J) + line('M87 149L128 176L168 149M85 178L104 199M171 178L152 199','#9ca6bf',5) + line('M49 70L66 98M207 70L191 98','#bfa17a',5)
icons['sovereign_ring'] = '<ellipse cx="128" cy="150" rx="62" ry="62" fill="none" stroke="#222d40" stroke-width="27"/><ellipse cx="128" cy="150" rx="62" ry="62" fill="none" stroke="url(#gold)" stroke-width="17"/>' + p('M81 52L107 68L128 35L149 68L175 52L168 108H88Z',G) + p('M103 83L128 64L153 83L146 114H110Z',J) + line('M81 145Q77 179 97 192','#fff0be',6)
icons['blood_sword'] = '<g transform="rotate(24 128 128)">' + p('M119 33L149 58L137 101L159 89L144 133L129 157H108L114 116L101 126L106 83Z',S) + p('M121 58L135 69L122 123L129 142L116 151Z',R) + p('M86 142L112 155H140L166 137L154 168L127 176L95 165Z',R) + p('M116 176H136V207H116Z',O) + circle(126,215,9,R) + '</g>'
icons['gold_sword'] = p('M165 34L195 63L164 111L152 110L143 136L121 154L98 132L116 109L142 99L141 86Z',G) + line('M171 55L116 131','#fff4c8',6) + p('M75 122L135 176L151 153L123 151L97 127L97 101Z',G) + p('M94 154L113 172L76 209L57 191Z',O) + p('M46 196L70 220L89 201L65 178Z',G) + p('M153 72L166 73L172 86L158 92L147 84Z',J)
icons['wolf_fang'] = line('M70 50Q118 25 163 56L174 85','#cfa56b',9) + p('M98 62Q162 41 187 91Q190 178 80 222Q119 168 100 130Q80 99 98 62Z','#f1e6c4') + p('M152 89L184 90Q181 158 103 205Q154 149 152 89Z','#b3b4a6') + p('M92 70Q131 48 180 76L184 102Q133 81 98 102Z',L) + line('M109 71L112 94M134 66L135 91M157 70L157 93','#e7c486',5)
icons['stone_heart'] = p('M40 95L71 54L111 53L130 78L153 46L194 65L216 116L186 170L126 220L68 177Z',O) + p('M71 54L111 53L130 78L103 126L40 95Z',S) + p('M153 46L194 65L169 120L130 78Z','#8aa4b0') + p('M103 126L130 98L150 122L139 160L111 169L93 150Z',J) + line('M103 126L68 177M139 160L126 213M150 122L203 115','#b5e1d6',6)
icons['spring_seed'] = p('M128 37C117 83 64 104 64 157C64 230 191 230 191 157C191 104 143 80 128 37Z',J) + p('M128 112Q173 155 150 191Q129 216 103 191Q79 159 128 112Z',L) + line('M129 180V107','#e6e6a8',7) + p('M129 133Q81 136 81 95Q117 91 129 133Z','#a6d791') + p('M130 111Q133 70 172 80Q176 112 130 124Z','#d6edba') + line('M85 152Q77 176 93 189','#e1fff0',6)
icons['lucky_coin'] = '<ellipse cx="132" cy="134" rx="83" ry="86" fill="url(#gold)"/><circle cx="123" cy="124" r="77" fill="url(#gold)"/><circle cx="123" cy="124" r="58" fill="#a7794c" stroke="#f9d893" stroke-width="5"/>' + p('M107 107H139V141H107Z',O) + line('M83 84L94 92M151 84L144 92M83 162L93 153M151 162L143 153','#ffe8a9',7) + line('M173 177L184 189M188 151L201 158','#81573e',5)
icons['crimson_chalice'] = line('M83 83H51V111Q51 145 99 140M173 83H205V111Q205 145 157 140','#dfb578',13) + p('M73 63H183L173 122Q167 151 139 157V188L177 204V218H79V204L117 188V157Q89 151 83 122Z',G) + '<ellipse cx="128" cy="66" rx="55" ry="17" fill="url(#red)"/>' + p('M128 94L142 118L128 140L114 118Z',R) + line('M94 91L100 120','#fff0bd',6)
icons['merchant_seal'] = p('M62 159L81 134L115 127L139 141L178 144L199 176L187 207L154 220L123 208L92 219L59 197Z',R) + p('M89 153L98 130H158L170 155V183H86Z',G) + p('M109 133L114 98Q83 87 91 63Q100 34 128 36Q159 34 168 63Q175 87 142 98L149 133Z',L) + line('M102 61Q109 48 126 50','#e4bc84',6) + line('M96 163H160','#fff0bc',6)
icons['sun_emblem'] = p('M128 33L144 73L178 49L173 88L214 87L187 119L222 141L182 150L192 193L153 179L128 222L108 180L68 197L76 155L35 142L69 118L43 86L84 88L79 48L112 73Z',G) + circle(128,127,49,'#bd7952') + circle(128,127,34,G) + p('M128 105L139 128L128 150L117 128Z','#fff1b7','stroke="none"')
icons['guardian_oath'] = p('M74 45H174L192 68L182 159L128 199L74 159L64 68Z',S) + p('M88 65H168L160 145L128 170L96 145Z',J) + p('M109 83H147V96H137V137H119V96H109Z',G) + p('M73 145Q126 170 185 145L201 172L177 187L186 217L128 198L72 217L81 187L55 172Z',G) + line('M90 178L126 185L164 177','#fff0ba',5)

for id, body in icons.items():
    (OUT / f'{id}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">\n' + DEFS + '\n<g stroke="#222d40" stroke-width="7" stroke-linejoin="round" stroke-linecap="round">' + body + '</g></svg>\n', encoding='utf-8')

items = {}
for filename in ['content.json', 'phase3_items.json']:
    items.update(json.loads((ROOT / 'data' / filename).read_text(encoding='utf-8'))['items'])
assert set(icons) == {id for id in items if not id.startswith('p3_')}
paths = {id: f'res://assets/items/{"phase3" if id.startswith("p3_") else "unique"}/icons/{id}.png' for id in items}
gd = 'extends RefCounted\n## Presentation-only registry; gameplay data and saved item dictionaries stay unchanged.\nconst PATHS := {\n'
gd += ''.join(f'\t"{id}": "{path}",\n' for id, path in paths.items())
gd += '}\n\nstatic func path_for(item: Dictionary) -> String:\n\tvar id := str(item.get("id", ""))\n\tif PATHS.has(id): return PATHS[id]\n\tvar explicit := str(item.get("icon", ""))\n\treturn explicit if explicit.begins_with("res://assets/items/") else ""\n'
(ROOT / 'scripts/ui/item_icon_registry.gd').write_text(gd, encoding='utf-8')
print(f'Authored {len(icons)} SVG sources; registered {len(paths)} unique item icons')

