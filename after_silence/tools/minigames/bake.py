"""Bake original native-resolution pixel art for the existing trial boards."""
import random
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets" / "minigames0310"
OUT.mkdir(parents=True, exist_ok=True)
names = "letter_press footprints reality tubes balance pairs seeds signal_grid railway lights echo_tuning shelves".split()
bases = ["504237","49504a","283745","34454b","4c413c","4b3748","414739","314340","3c4650","43394a","37394e","493d3b"]
trims = ["d8ab7d","c7b08b","9bb6c7","a2c4c4","d2a572","cba0bd","aebd85","d7b684","b8b5c8","debd81","bba8d7","c6aa92"]

def rgb(hexcode):
    return tuple(bytes.fromhex(hexcode))

def shade(color, value):
    return tuple(max(0,min(255,c+value)) for c in color)

theme = Image.new("RGBA",(3*112,4*80))
for i, name in enumerate(names):
    w,h=112,80
    base, accent = rgb(bases[i]),rgb(trims[i])
    sheet=Image.new("RGB",(w,h),base)
    d=ImageDraw.Draw(sheet)
    rng=random.Random(1993+i*177)
    for y in range(h):
        for x in range(w):
            variation=rng.choices((-8,-3,0,3,8),(4,18,54,19,5))[0]
            distance=max(abs(y-h/2)-23,abs(x-w/2)-35,0)
            d.point((x,y),shade(base,int(variation-distance*.73)))
    if name in ("letter_press","balance","shelves","railway"):
        for y in range(7,h,13):
            d.line((0,y,w,y),fill=shade(base,-14))
            d.line((0,y+1,w,y+1),fill=shade(base,11))
            for x in range(-12+y%17,w,24):
                d.line((x,y+2,x+13,y+2),fill=shade(base,-4))
                d.point((x+17,y+3),fill=shade(base,13))
    elif name in ("pairs","lights","echo_tuning"):
        for y in range(5,h,6):
            for x in range(-3+y%4,w,6):
                d.line((x,y,x+2,y),fill=shade(base,8))
                d.point((x+1,y+1),fill=shade(base,-9))
        for cx in [9,102]:
            for y in (13,65):
                d.polygon([(cx-4,y),(cx,y-3),(cx+4,y),(cx,y+3)],outline=shade(base,19))
    elif name in ("signal_grid","tubes"):
        for x in range(3,w,10):
            d.line((x,3,x,h),fill=shade(base,-6))
        for y in range(3,h,10):
            d.line((0,y,w,y),fill=shade(base,-5))
        for x,y in [(9,10),(17,21),(103,62),(91,70),(7,66)]:
            d.line((x,y,x+4,y,x+4,y+3,x+8,y+3),fill=shade(base,18))
    else:
        for _ in range(77):
            x,y=rng.randrange(w),rng.randrange(h)
            d.line((x,y,x+rng.randrange(1,5),y),fill=shade(base,rng.choice([-12,10])))
    for x in (3,w-4):
        for y in (3,h-4):
            d.rectangle((x-1,y-1,x+1,y+1),fill=shade(base,-22))
            d.point((x,y),fill=shade(accent,-24))
    theme.paste(sheet,((i%3)*w,(i//3)*h))
theme.save(OUT/"stages.png")

# Atlas of objects and controls. All hues also have a silhouette or glyph.
icons=Image.new("RGBA",(24*8,24*3))
INK="#242331"; COPPER="#b78d67"; CREAM="#f0d29d"; MINT="#acc9a4"; ASH="#5b6374"
def put(i,draw_fn):
    tile=Image.new("RGBA",(24,24))
    draw_fn(ImageDraw.Draw(tile))
    icons.paste(tile,((i%8)*24,(i//8)*24))

def lamp(d, lit):
    d.polygon([(4,20),(4,8),(8,4),(10,4),(10,1),(13,1),(13,4),(16,4),(20,8),(20,20),(17,23),(7,23)],fill=INK)
    d.rectangle((7,8,17,19),fill="#d19b59" if lit else "#526477",outline=COPPER)
    d.rectangle((9,10,15,16),fill="#f7d999" if lit else "#363e52")
    d.line((10,10,10,15),fill="#fff0be" if lit else "#738894")
    d.rectangle((6,20,18,21),fill="#74553f")
def herb(d,color):
    d.line((12,22,12,6),fill="#746147",width=3)
    for pts in [[(12,11),(7,5),(2,5),(4,11),(10,14)],[(12,17),(16,9),(22,9),(20,15),(13,19)],[(12,8),(10,5),(12,1),(15,2),(15,6)]]:
        d.polygon(pts,fill=color,outline=INK)
    d.point((7,7),fill=CREAM)
def circuit(d,on):
    if on:
        d.rectangle((0,9,23,14),fill="#564541",outline=INK)
        d.line((0,11,23,11),fill=CREAM,width=2)
    else:
        d.rectangle((9,0,14,23),fill="#564541",outline=INK)
        d.line((11,0,11,23),fill=COPPER,width=2)
    d.rectangle((8,8,15,15),fill=COPPER,outline=INK)
    d.rectangle((10,10,13,13),fill=CREAM)
def rail(d):
    for y in (8,17):
        d.line((1,y,22,y),fill=ASH,width=3)
        d.line((2,y-1,21,y-1),fill="#dae0d5")
    for x in (4,10,16):
        d.line((x,5,x,20),fill="#8b6e57")
    d.line((3,18,20,6),fill="#d3a36d",width=2)
def seed(d):
    d.polygon([(3,8),(17,4),(22,9),(18,18),(6,20),(2,15)],fill=INK)
    d.polygon([(4,9),(16,6),(20,9),(17,16),(6,18),(4,14)],fill="#907459")
    d.line((6,12,15,8),fill=CREAM)
def back(d):
    d.rounded_rectangle((3,1,20,22),radius=2,fill=INK)
    d.rectangle((5,3,18,20),fill="#6a5368",outline=COPPER)
    d.polygon([(7,11),(11,6),(16,11),(11,17)],outline=CREAM)
    d.point((11,11),fill=CREAM)
def spark(d):
    d.polygon([(11,0),(14,7),(21,7),(17,12),(22,19),(15,18),(11,23),(8,17),(1,18),(6,12),(1,6),(8,7)],fill="#804c54",outline=INK)
    d.polygon([(11,4),(14,10),(19,12),(14,14),(11,20),(9,14),(4,12),(9,9)],fill="#db967d")
    d.rectangle((10,10,13,13),fill=CREAM)
def shield(d):
    d.polygon([(12,2),(21,5),(20,15),(12,22),(4,16),(3,6)],fill="#3b5457",outline=INK)
    d.polygon([(12,5),(18,7),(17,15),(12,19),(7,15),(6,8)],outline=MINT)
    d.line((12,8,12,15),fill=CREAM,width=2)
def flag(d):
    d.rectangle((5,2,7,22),fill=COPPER,outline=INK)
    d.polygon([(7,3),(22,4),(18,10),(22,15),(7,14)],fill=MINT,outline=INK)
    d.line((8,5,16,5),fill=CREAM)
def weight(d):
    d.polygon([(4,8),(8,6),(8,2),(15,2),(15,6),(19,8),(22,21),(2,21)],fill=INK)
    d.polygon([(6,9),(17,9),(20,19),(4,19)],fill="#8d776a")
    d.line((8,10,16,10),fill=CREAM)
    d.rectangle((10,4,13,6),fill=ASH)
def vase(d):
    d.polygon([(7,2),(17,2),(16,7),(20,13),(19,21),(5,21),(4,13),(8,7)],fill=INK)
    d.polygon([(9,4),(15,4),(14,8),(18,14),(16,19),(7,19),(6,14),(10,8)],fill="#657c82")
    d.line((8,14,16,14),fill=MINT,width=2)
    d.rectangle((6,1,18,3),fill=COPPER)
def water(d):
    d.polygon([(12,2),(19,12),(19,18),(15,22),(8,22),(4,18),(4,13)],fill=INK)
    d.polygon([(12,5),(17,13),(17,18),(13,20),(8,19),(6,16),(7,12)],fill="#82b8bd")
    d.line((8,14,8,17),fill="#d8eaeb")
def gear(d):
    d.rectangle((7,3,16,21),fill=INK)
    d.rectangle((3,7,20,16),fill=INK)
    d.ellipse((5,5,18,18),fill=COPPER,outline=CREAM)
    d.rectangle((10,10,13,13),fill=INK)

for i, fn in enumerate([lambda d:lamp(d,False),lambda d:lamp(d,True),lambda d:herb(d,"#a6b775"),lambda d:herb(d,"#a77e99"),
                        lambda d:circuit(d,True),lambda d:circuit(d,False),rail,seed,back,spark,shield,flag,weight,vase,water,gear]):
    put(i,fn)
icons.save(OUT/"objects.png")

# Preserve the floor, wall and door mapping expected by the maze model.
maze=Image.new("RGBA",(8*28,2*28))
for mirrored in range(2):
    cold=("#42536a","#556e82","#293847") if mirrored else ("#434b52","#62716d","#2c363b")
    for column in range(8):
        tile=Image.new("RGBA",(28,28),cold[2])
        d=ImageDraw.Draw(tile)
        if column<3:
            d.rectangle((0,0,27,26),fill=cold[0])
            d.line((0,0,27,0),fill=cold[1])
            d.line((6+column*6,20,14+column*6,20),fill=cold[2])
            d.point((10,9+column*4),fill=cold[1])
        elif column<5:
            for i in range(3):
                y=i*8
                d.rectangle((0,y,27,y+6),fill=cold[0])
                d.line((1,y,26,y),fill=cold[1])
                d.line((11+(i%2)*9,y,11+(i%2)*9,y+6),fill=cold[2])
            d.rectangle((0,24,27,27),fill="#222732")
        else:
            rim=["#c09477","#a1bca8","#a999c2"][column-5]
            d.rectangle((0,0,27,27),fill=cold[0])
            d.polygon([(4,26),(4,11),(7,5),(11,2),(16,2),(21,5),(24,11),(24,26)],fill="#212535",outline=rim,width=2)
            d.rectangle((8,24,20,26),fill=rim)
            d.point((5,14),fill="#e0d0b2")
        maze.paste(tile,(column*28,mirrored*28))
maze.save(OUT/"maze.png")

# Eight-frame overlay for victory or safe retry. No fullscreen flashes.
strip=Image.new("RGBA",(8*48,48))
for frame in range(8):
    cell=Image.new("RGBA",(48,48))
    d=ImageDraw.Draw(cell)
    ring=12+frame//2
    for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(.7,.7),(-.7,.7),(.7,-.7),(-.7,-.7)]:
        x,y=24+int(ring*dx),24+int(ring*dy)
        d.line((x-2,y,x+2,y),fill=(*rgb("dcc097"),max(0,220-frame*23)))
        if frame<5: d.line((x,y-2,x,y+2),fill=(*rgb("fff2c7"),210-frame*30))
    d.polygon([(24,11),(36,23),(24,35),(12,23)],fill="#294246",outline="#b9cba6")
    d.line((18,23,22,27,30,18),fill="#e0e6be",width=2)
    strip.paste(cell,(frame*48,0))
strip.save(OUT/"success.png")
