"""Original props and room dressing for the story investigations."""
from pathlib import Path
import random
from PIL import Image, ImageDraw

out=Path(__file__).resolve().parents[2]/"assets"/"investigations0320"
out.mkdir(parents=True,exist_ok=True)
icons=["notice","ribbon","clock","lamp","door","papers","stamp","desk","gear","rope","gauge","cup","flag","whistle","ticket","post","stone","scope"]
atlas=Image.new("RGBA",(24*6,24*3))
shadow="#211e26"; wood="#795a47"; gold="#d4ae79"; paper="#d9c1a1"; shade="#544640"; ink="#5e5356"
for index,name in enumerate(icons):
    tile=Image.new("RGBA",(24,24)); d=ImageDraw.Draw(tile)
    if name in ["notice","papers","desk","ticket"]:
        d.rectangle((2,6,21,20),fill=shadow)
        d.rectangle((4,5,19,17),fill=wood)
        for x,y in [(5,4),(8,7)]:
            d.polygon([(x,y),(x+10,y),(x+11,y+11),(x+1,y+12)],fill=paper,outline=shade)
            for j in range(3): d.line((x+3,y+3+j*2,x+8,y+3+j*2),fill=ink)
        d.point((18,16),fill=gold)
        if name=="notice": d.rectangle((3,21,5,23),fill=shade); d.rectangle((18,21,20,23),fill=shade)
    elif name in ["clock","gear","gauge","scope"]:
        d.ellipse((2,3,22,21),fill=shadow)
        d.ellipse((4,4,20,19),fill=wood,outline=gold)
        d.ellipse((7,6,17,17),fill=paper if name!="scope" else "#657e83")
        if name in ["clock","gauge"]:
            d.line((12,8,12,12,16,14),fill=shade,width=2)
            d.point((9,9),fill="#a37863")
        else:
            d.rectangle((10,9,15,14),fill=shade)
            d.point((9,9),fill=gold)
    elif name in ["lamp","door"]:
        d.polygon([(4,22),(4,8),(7,5),(11,2),(15,3),(20,7),(21,22)],fill=shadow)
        d.polygon([(6,21),(6,9),(11,5),(15,5),(19,9),(19,21)],fill=wood,outline=gold)
        if name=="lamp":
            d.rectangle((9,10,16,17),fill="#e0ac71")
            d.rectangle((11,11,13,15),fill="#f6d8a0")
        else:
            for x in (9,13,16): d.line((x,8,x,20),fill=shade)
            d.rectangle((15,14,17,16),fill=gold)
    elif name in ["ribbon","flag","post","rope"]:
        d.line((8,4,8,22),fill=shadow,width=4)
        d.line((8,4,8,21),fill=wood,width=2)
        d.polygon([(8,7),(21,7),(18,11),(21,15),(8,14)],fill="#a17671" if name=="ribbon" else "#839787",outline=shade)
        d.line((10,8,17,8),fill=paper)
    elif name in ["cup","stamp","whistle"]:
        d.rectangle((3,8,19,18),fill=shadow)
        d.polygon([(5,7),(18,7),(17,16),(7,17)],fill=wood,outline=gold)
        d.line((7,9,15,9),fill=paper)
        d.rectangle((8,19,17,20),fill=shade)
    else:
        d.polygon([(3,20),(4,13),(10,6),(16,5),(22,14),(21,21)],fill="#677375",outline=shadow)
        d.polygon([(7,13),(11,8),(15,7),(17,11),(13,14)],fill="#9aa39b")
        d.line((14,12,15,15,18,16),fill=shade)
    atlas.paste(tile,((index%6)*24,(index//6)*24))
atlas.save(out/"clues.png")

for name,base,grain,edge in [
    ("paper","#8a705d","#997f66","#514449"),
    ("metal","#536460","#677870","#354946"),
]:
    surface=Image.new("RGB",(96,64),base)
    d=ImageDraw.Draw(surface)
    rng=random.Random(2218)
    for y in range(0,64,8 if name=="paper" else 16):
        d.line((0,y,96,y),fill=edge)
        d.line((0,y+1,96,y+1),fill=grain)
        for x in range(11+y%29,96,24 if name=="paper" else 18):
            d.line((x,y,x,y+(7 if name=="paper" else 15)),fill=edge)
    for _ in range(125):
        x,y=rng.randrange(96),rng.randrange(64)
        d.line((x,y,x+rng.randrange(0,5),y),fill=grain)
    surface.save(out/(name+".png"))

# Each wide prop is authored at half its in-game size, including its feet and trim.
fixtures = Image.new("RGBA", (192, 104))
d = ImageDraw.Draw(fixtures)

def archive_desk(x, y):
    d.polygon([(x+1,y+5),(x+74,y+5),(x+79,y+16),(x+79,y+23),(x+2,y+23),(x+2,y+17)],
              fill="#342a25")
    d.rectangle((x+7,y+22,x+12,y+26), fill="#4a352b")
    d.rectangle((x+68,y+22,x+73,y+26), fill="#4a352b")
    d.polygon([(x+6,y+7),(x+73,y+7),(x+76,y+16),(x+4,y+16)], fill="#9b714f")
    d.rectangle((x+5,y+17,x+76,y+21), fill="#6b4d36")
    for i in range(4):
        d.line((x+10+i*13,y+9+i%3,x+21+i*13,y+9+i%3), fill="#af845b")
    for a,b,cover in [(10,8,"#565e59"),(16,9,"#896359"),(44,7,"#66656a"),(60,10,"#7c674f")]:
        d.rectangle((x+a,y+b,x+a+10,y+b+6), fill="#4f3d32")
        d.rectangle((x+a+1,y+b,x+a+9,y+b+4), fill=cover)
        d.line((x+a+2,y+b+5,x+a+9,y+b+5), fill="#c7ad88")
    d.polygon([(x+27,y+8),(x+43,y+9),(x+40,y+15),(x+24,y+15)], fill="#ddc6a0")
    d.line((x+29,y+10,x+39,y+11), fill="#8c7963")
    d.line((x+27,y+13,x+34,y+13), fill="#8c7963")

def pump_body(x, y):
    d.rounded_rectangle((x+9,y+10,x+69,y+22),radius=4,fill="#293734",outline="#29322e")
    for a in (9, 20, 53, 64):
        d.rectangle((x+a,y+19,x+a+6,y+26),fill="#3b4943")
        d.line((x+a,y+25,x+a+6,y+25),fill="#697268")
    d.rectangle((x+22,y+6,x+56,y+21),fill="#30413e",outline="#263130")
    d.rectangle((x+24,y+8,x+54,y+12),fill="#7c8d80")
    d.rectangle((x+25,y+13,x+53,y+19),fill="#4d6159")
    for a in (13, 58):
        d.rectangle((x+a,y+11,x+a+8,y+20),fill="#89674f")
        d.line((x+a+1,y+11,x+a+7,y+11),fill="#c09b71")
        d.point((x+a+4,y+14),fill="#604e3e")
    for a in (32, 47):
        d.ellipse((x+a-4,y+1,x+a+4,y+10),fill="#303633",outline="#a78263")
        d.ellipse((x+a-2,y+3,x+a+2,y+8),fill="#c6b891")
        d.line((x+a,y+6,x+a+1,y+4),fill="#70624d")
    d.rectangle((x+36,y+19,x+46,y+23),fill="#a77b56")
    d.line((x+38,y+20,x+44,y+20),fill="#d0a572")

def press(x, y):
    d.rectangle((x+4,y+25,x+47,y+32),fill="#372c25")
    d.rectangle((x+8,y+22,x+43,y+29),fill="#76543a")
    d.rectangle((x+10,y+3,x+40,y+6),fill="#634937")
    for a in (12,36):
        d.rectangle((x+a,y+6,x+a+4,y+23),fill="#886141")
        d.line((x+a+1,y+7,x+a+1,y+21),fill="#bc9262")
    d.rectangle((x+24,y+2,x+28,y+17),fill="#555954")
    d.line((x+17,y+9,x+34,y+9),fill="#ab835b",width=2)
    d.rectangle((x+19,y+16,x+33,y+20),fill="#4d4540")
    d.rectangle((x+17,y+21,x+35,y+23),fill="#d8b88c")

archive_desk(0,0)
pump_body(0,32)
press(0,64)

# Floor grate. The background remains transparent between the outer bolts.
d.rectangle((82,69,151,91),fill="#263733")
d.rectangle((84,71,149,89),fill="#677971")
d.rectangle((86,73,147,87),fill="#354743")
for x in range(89,148,5):
    d.line((x,74,x,86),fill="#7c887c",width=2)
    d.line((x+2,74,x+2,86),fill="#233533")
for x,y in [(84,71),(149,71),(84,89),(149,89)]:
    d.point((x,y),fill="#b09b78")
fixtures.save(out/"fixtures.png")
