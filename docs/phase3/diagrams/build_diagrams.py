"""Build the design-only SVG atlas. Python standard library; no game data writes."""
from pathlib import Path
from html import escape

ROOT = Path(__file__).resolve().parent
BG = '#101923'
PANEL = '#1b2937'
TEXT = '#eef4f7'
MUTED = '#a9bfcc'
TEAL = '#72d4c4'
GOLD = '#edca85'
RED = '#efa59d'


class Diagram:
    def __init__(self, width, height, title, subtitle):
        self.width, self.height = width, height
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img">',
                      f'<title>{escape(title)}</title>',
                      f'<desc>{escape(subtitle)}</desc>',
                      '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#72d4c4"/></marker></defs>',
                      f'<rect width="{width}" height="{height}" fill="{BG}"/>']
        self.text(48, 58, title, 32, TEXT)
        self.text(48, 94, subtitle, 17, MUTED)

    def text(self, x, y, copy, size=19, color=TEXT, anchor='start'):
        self.parts.append(f'<text x="{x}" y="{y}" fill="{color}" font-family="Microsoft YaHei, Noto Sans SC, sans-serif" font-size="{size}" text-anchor="{anchor}">{escape(copy)}</text>')

    def rect(self, x, y, w, h, fill=PANEL, stroke='#344a5a', radius=12):
        assert 0 <= x <= self.width-w and 0 <= y <= self.height-h
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}"/>')

    def card(self, x, y, w, h, title, lines, accent=TEAL):
        self.rect(x,y,w,h)
        self.rect(x,y,5,h,accent,accent,2)
        self.text(x+22,y+36,title,23,accent)
        for i,line in enumerate(lines):
            assert 70+i*30 < h-5, (title, h, line)
            self.text(x+22,y+70+i*30,line,18)

    def arrow(self, points, dashed=False):
        pts=' '.join(f'{x},{y}' for x,y in points)
        dash=' stroke-dasharray="7 6"' if dashed else ''
        self.parts.append(f'<polyline points="{pts}" fill="none" stroke="{TEAL}" stroke-width="2.4" marker-end="url(#arrow)"{dash}/>')

    def save(self, name):
        self.text(48,self.height-24,'第三阶段设计稿 v0.1 · 2026-10-01 · 规划图，不代表功能已实现；详细规则以对应正文为准。',15,MUTED)
        (ROOT/name).write_text('\n'.join(self.parts+['</svg>']),encoding='utf-8')


def roadmap():
    d=Diagram(1560,1120,'第三阶段 / 从构筑选择到完整重玩循环','五份设计文档 · 保留十层与确定性预览 · 首个交付切片：前三种机制遗物＋前五层＋誓约遗迹')
    d.card(48,140,440,190,'01 构筑与物品',['22 件现有物品作为基线','6 件新增机制遗物，分两批开放','先检查阈值收益，再调投放与价格'])
    d.card(560,140,440,190,'02 探索与遗迹',['三事件槽 → 三座可回访遗迹','清晰成本 / 互斥收益 / 免费离开','固定成长、钥匙与安全主路保留'])
    d.card(1072,140,440,190,'03 敌人与首领',['十种敌人基线＋三种可选变体','狂怒、石甲与新遗物共用时序','攻击、受击、机制、击败动作'])
    d.card(305,390,440,190,'04 挑战与解锁',['C0 / C1 / C2 与四种起点','成就开放新玩法，不无限堆数值','图鉴、只读复盘、局末一次提交'])
    d.card(815,390,440,190,'05 教学与模型动画',['八个操作触发教学节点','公主四向行走与战斗分层母版','动画读战报；跳过不影响奖励'])
    d.arrow([(268,330),(268,355),(525,355),(525,390)])
    d.arrow([(780,330),(780,365),(525,365),(525,390)])
    d.arrow([(1292,330),(1292,355),(1035,355),(1035,390)])
    d.arrow([(780,330),(780,365),(1035,365),(1035,390)])
    d.text(48,638,'开发门槛 / 按结果验收推进',24,GOLD)
    stages=[('A 规则与兼容',['旧局不改数值','新效果可追溯']),('B 前五层闭环',['三路线可过牛头','R1 可选择可回访']),('C 动画样板',['四向步态正确','牛头机制可读']),('D 十层扩展',['R2 / R3 与后段怪','零火种完整通关']),('E–G 解锁与验收',['挑战、教学、图鉴','整塔平衡与试玩'])]
    for i,(title,lines) in enumerate(stages):
        x=48+i*300
        d.card(x,676,268,155,title,lines,GOLD)
        if i<4:d.arrow([(x+268,751),(x+296,751)])
    d.card(48,875,714,156,'交付约束',['装备机会 ≤14，遗物机会 ≤17；三遗迹替换原事件','所有新数值为初值；不将设计文档视为测试证据'],TEAL)
    d.card(798,875,714,156,'完成证据',['生产接口的参考路线、资源曲线、旧局兼容日志','逐帧联系图、小尺寸预览、真实界面与试玩记录'],GOLD)
    d.save('phase3-roadmap.svg')


def ruins():
    d=Diagram(1640,1450,'遗迹规划 / 每次选择都能看清代价','三处设施替换第 2 / 6 / 9 层事件；不会额外增加装备或遗物机会。地图为拓扑样板。')
    d.card(48,140,730,172,'2F · R1 誓约遗迹',['锋刃：生命 −12 → 攻击 +2（须保留 1 HP）','守御：金币 −15 → 防御 +1；搜寻：免费获得 8 金币','三项互斥；稍后再来不消耗遗迹'])
    d.card(816,140,776,172,'6F · R2 断誓锻台',['锻造：25 金币 → 攻击 +4','熔铸：基础最大生命 −10 → 攻击 +4；当前生命按新上限截断','搜寻：免费获得 15 金币；也可稍后再来'],GOLD)
    d.card(48,344,730,172,'9F · R3 守灯圣所',['恢复 35 HP / 防御 +2 / 生命 −12 换 30 金币','三选一；满血禁用治疗，费用不足显示原因','本层休息点是另一实体，两者状态分别保存'])
    d.card(816,344,776,172,'机会与强度账本',['遗迹只改资源与基础属性，不产出新物品','三处事件 = 三次收益；离开、读档、重试不刷新','直接收益另列预算；全部路径须用整塔模拟验证'],GOLD)
    d.text(48,564,'R1 提交路径 / 任何结果都先预览',24,TEAL)
    d.card(48,595,260,122,'查看遗迹',['读取本局冻结选项'])
    d.card(360,595,340,122,'选择与费用校验',['HP ≥13 / 金币 ≥15'])
    d.card(752,595,330,122,'确认候选事务',['费用＋收益＋耗尽标记'])
    d.card(1134,595,458,122,'保存成功 → 展示结果',['保存失败保持旧状态并重试'])
    d.arrow([(308,655),(356,655)])
    d.arrow([(700,655),(748,655)])
    d.arrow([(1082,655),(1130,655)])
    d.text(365,751,'费用不足：不提交。稍后再来：保留 available。已领取：仅查看铭文。',19,MUTED)
    d.text(48,811,'11×11 地图布局样板',24,GOLD)
    rows=['###########','#####U#####','#####.#####','#R....#####','#####.#####','#####..G.T#','#####.#####','#P.......K#','#####.#####','#####D#####','###########']
    x0,y0,cell=48,842,43
    colors={'#':'#243443','.':'#527082','D':'#72d4c4','U':'#72d4c4','R':'#edca85','G':'#efa59d','T':'#aab4ee','P':'#89bded','K':'#aab4ee'}
    for y,row in enumerate(rows):
        for x,ch in enumerate(row):
            d.rect(x0+x*cell,y0+y*cell,cell-3,cell-3,colors[ch],BG,3)
            if ch not in '#.':d.text(x0+x*cell+20,y0+y*cell+28,ch,23,BG,'middle')
    d.card(568,842,1024,192,'图例与访问规则',['D 来路 / U 去路：中轴安全通道，不要求使用遗迹','R 遗迹：单格入口＋选项面板；G 守卫：不可绕过后取 T 奖励','P 补给 / K 固定成长占位：沿用原关卡条件与预算','实际生成时另预留商人、休息、钥匙槽，不覆盖既有实体'],GOLD)
    d.card(568,1066,1024,222,'遗迹资源制作与状态',['R1 石台：断剑、灯座、符文；R2 锻台：铁砧、炉心、烟','R3 圣所：石灯、火芯与光路；可用与耗尽有不同轮廓/标识','三设施共 35 帧位：12 待机＋20 解决＋3 耗尽静态','主体单格；光晕最多 1.2 格；不得遮挡邻格门、钥匙和提示','以脚底锚点注册图像，不用自动裁切中心定位'],TEAL)
    d.save('ruin-plan.svg')


def animation():
    d=Diagram(1560,1200,'模型与动画 / 先提交结果，再呈现动作','2D 分层母版 → 透明 PNG 帧 → SpriteFrames / 现有自绘组件；保持右剑左灯与四向独立视图。')
    d.card(48,138,460,202,'公主地图模型',['128×128 运行帧，脚底 (64,116)','四向 idle 16帧 / walk 24帧','四向 interact 16帧；合计 56帧','禁止水平镜像造成左右手交换'])
    d.card(550,138,460,202,'公主战斗模型',['384×384 运行帧，脚底 (192,348)','idle 6 / attack 8 / guard 4 / hit 3','victory 8 / defeat 6；合计 35帧','骨架只用于制作，运行优先烘焙帧'])
    d.card(1052,138,460,202,'怪物与场景',['普通怪 / 精英 / Boss：236战斗帧位','地图视角待机烘焙需单独计量','三遗迹 35帧；六新遗物图标','地图敌人不巡逻，无通用行走需求'],GOLD)
    d.text(48,393,'单次战斗事务',24,TEAL)
    transaction=[('确认',['校验当前输入']),('模拟',['完整真实战报']),('保存',['run / meta 原子提交']),('演出',['只读回放，可跳过']),('结果',['探索或剧情衔接'])]
    for i,(title,lines) in enumerate(transaction):
        x=48+i*300
        d.card(x,422,268,122,title,lines)
        if i<4:d.arrow([(x+268,481),(x+296,481)])
    d.text(648,579,'保存失败停留此处 → 同一候选重试；不先播领取成功。',18,RED)
    d.text(48,638,'攻击源动作 / 8 帧 @16 FPS / 0.50 秒',24,GOLD)
    for i in range(8):
        x=48+i*183
        col=GOLD if i in (3,4) else TEAL
        d.rect(x,668,167,95,PANEL,col)
        d.text(x+18,702,f'帧 {i}',22,col)
        d.text(x+18,735,'命中' if i in (3,4) else ('蓄力' if i<3 else '回收'),18)
    d.text(48,800,'命中点为帧 3；只在此显示数字和特效，不在帧回调中扣血或发奖。',20,MUTED)
    d.card(48,847,714,220,'战报到画面的对应',['保留最后一击、首次机制触发与阶段阈值','长战斗最多展示六个真实回合；完整战报不截断','反伤击杀必须表现为反击后的反伤，不能伪造挥剑','目标时长：普通1.2–3秒 / 精英≤4秒 / Boss首次≤6秒','减动效：静态结果与文字；静音：信息仍然完整'],TEAL)
    d.card(798,847,714,220,'验收不是只看一张关键帧',['行走必须左右脚交替；接触帧脚底偏差≤1像素','26 / 33 / 47px 地图格检查轮廓和方向','提供逐帧联系图、原速录屏、小尺寸实机渲染图','跳过、重进、保存重试均与战报数值一致','新增动画驻留目标≤48 MiB，实施后实测'],GOLD)
    d.save('animation-timeline.svg')


def gallery():
    cards=[('phase3-roadmap.svg','总体开发依赖图'),('ruin-plan.svg','遗迹决策与地图规划'),('animation-timeline.svg','模型动画与事务时序')]
    blocks=''.join(f'<section id="d{i}"><h2>{title}</h2><a href="{file}" target="_blank">打开原尺寸 SVG</a><img src="{file}" alt="{title}" loading="lazy"/></section>' for i,(file,title) in enumerate(cards))
    (ROOT/'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>塔境 · 第三阶段规划图册</title><style>body{margin:0;background:#101923;color:#eef4f7;font:16px/1.7 'Microsoft YaHei',sans-serif}header,main{max-width:1400px;margin:auto;padding:24px}h1{font-size:30px}h2{font-size:23px}p{color:#a9bfcc}a{color:#72d4c4}nav{display:flex;gap:24px;flex-wrap:wrap}section{margin:32px 0 56px}img{display:block;width:100%;height:auto;margin-top:16px;border:1px solid #344a5a;border-radius:12px}footer{padding:24px;color:#a9bfcc}</style><header><h1>塔境 · 第三阶段规划图册</h1><p>设计稿 v0.1 · 2026-10-01。五份详细设计位于上级目录；这些图是可实施规划，不代表功能或素材已经完成。</p><nav><a href="#d0">开发依赖</a><a href="#d1">遗迹规划</a><a href="#d2">模型动画</a><a href="../README.md">设计总册</a></nav></header><main>'''+blocks+'''</main><footer>本图册无外部依赖，可离线查看。原始图形为 SVG，生成源为 build_diagrams.py。</footer></html>''',encoding='utf-8')


if __name__=='__main__':
    roadmap()
    ruins()
    animation()
    gallery()
    print('Generated 3 SVG diagrams and index.html')
