"""Draw the garden trial sheet on a 24-pixel grid, using straight alpha."""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets/minigames0310/garden.png"
sheet = Image.new("RGBA", (24 * 8, 24))

def frame(i):
    image = Image.new("RGBA", (24, 24))
    brush = ImageDraw.Draw(image)
    brush.ellipse((3, 19, 20, 22), fill="#18192298")
    if i == 0:
        brush.polygon([(6, 15), (7, 11), (11, 7), (16, 7), (18, 11), (18, 14),
                       (15, 17), (9, 18)], fill="#4e3a36")
        brush.polygon([(7, 14), (8, 10), (12, 7), (16, 8), (17, 12), (14, 15),
                       (9, 17)], fill="#bc8761")
        brush.line((9, 12, 12, 9, 15, 9), fill="#e9bc85")
        brush.line((8, 15, 12, 13, 14, 11), fill="#745232")
    else:
        brush.polygon([(2, 16), (22, 16), (20, 21), (4, 21)], fill="#624741")
        brush.polygon([(2, 16), (6, 13), (18, 13), (22, 16), (19, 18),
                       (5, 18)], fill="#9c7056")
        brush.line((6, 14, 11, 14, 12, 15, 16, 15), fill="#d2a276")
        brush.line((6, 17, 18, 17), fill="#755247")
        brush.point([(5, 16), (16, 13), (19, 16), (8, 20), (17, 19)], fill="#c0916e")
        if i >= 2:
            height = min(i-2, 3)
            top = 10-height*2
            brush.line((12, 16, 12, top), fill="#89ab79", width=2)
            brush.polygon([(12, top+4), (7, top+1), (6, top+3), (8, top+5),
                           (12, top+6)], fill="#71a179")
            if height:
                brush.polygon([(13, top+4), (16, top+1), (19, top+1), (17, top+4),
                               (13, top+6)], fill="#b0c58b")
            if height == 3:
                brush.polygon([(10, 6), (8, 4), (10, 2), (14, 2), (16, 4),
                               (14, 6)], fill="#e0c392")
                brush.point((12, 4), fill="#fff0ad")
            if i in (6, 7):
                brush.point((4+i, 11+i%2), fill="#b5d8d1")
                brush.line((17-i%2, 7+i%2, 17-i%2, 8+i%2), fill="#8abcb9")
    return image

for index in range(8):
    sheet.paste(frame(index), (24 * index, 0))
sheet.save(OUT)
