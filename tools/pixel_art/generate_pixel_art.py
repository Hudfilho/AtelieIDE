"""Arte provisória do balcão em pixel art (M6).

Gera em art/pixel/ os PNGs do balcão e uma fonte bitmap própria (BMFont) em
dois tamanhos. Tudo é placeholder original, desenhado por código para caber
num balcão de 640x360 com escala inteira; troque os arquivos quando houver
arte de verdade. Rodar: python tools/pixel_art/generate_pixel_art.py
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "pixel")
os.makedirs(OUT, exist_ok=True)

# Paleta limitada, quente e escura.
P = {
    "void": (26, 16, 22), "night0": (20, 26, 51), "night1": (31, 42, 77), "night2": (47, 63, 107),
    "night3": (74, 91, 140), "city": (15, 18, 36), "lamp": (240, 200, 96), "lamp2": (255, 232, 150),
    "wood0": (43, 26, 23), "wood1": (61, 38, 32), "wood2": (79, 50, 35), "wood3": (107, 69, 48),
    "wood4": (138, 90, 59), "wood5": (168, 116, 74),
    "parch0": (232, 213, 163), "parch1": (217, 191, 133), "parch2": (196, 164, 104), "parch3": (156, 122, 74),
    "ink": (42, 29, 20), "note": (239, 227, 192), "note_edge": (185, 155, 98),
    "red0": (110, 28, 22), "red1": (163, 38, 30), "red2": (208, 64, 47),
    "green0": (35, 70, 34), "green1": (47, 95, 46), "green2": (79, 138, 59), "green3": (121, 176, 79), "green4": (168, 208, 106),
    "brass0": (122, 84, 30), "brass1": (184, 134, 47), "brass2": (224, 182, 81), "brass3": (245, 220, 138),
    "iron0": (42, 42, 48), "iron1": (74, 74, 82), "iron2": (122, 122, 134),
    "cloak0": (69, 41, 31), "cloak1": (90, 58, 44), "cloak2": (122, 79, 56),
    "white": (244, 238, 222), "tongue": (208, 90, 110), "leather0": (74, 32, 26), "leather1": (107, 47, 37), "leather2": (138, 61, 47),
    "grey0": (96, 96, 104), "grey1": (168, 168, 176), "grey2": (208, 208, 214),
}


def rgba(name, alpha=255):
    return P[name] + (alpha,)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, name):
    img.save(os.path.join(OUT, name))


def outline(img, color="void"):
    """Contorno de 1px em volta de tudo que é opaco (vizinhança 4)."""
    src = img.copy()
    px, out = src.load(), img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    out[x, y] = rgba(color)
                    break
    return img


def speckle(img, box, colors, step, seed):
    """Pontinhos regulares-irregulares para dar textura sem ruído aleatório real."""
    px = img.load()
    x0, y0, x1, y1 = box
    n = seed
    for y in range(y0, y1):
        for x in range(x0, x1):
            n = (n * 1103515245 + 12345) & 0x7FFFFFFF
            if n % step == 0 and px[x, y][3] != 0:
                px[x, y] = rgba(colors[n % len(colors)])


# ======================================================================
# Fonte bitmap (BMFont): 11 linhas por glifo. Linhas 0-1: acentos das
# maiúsculas; 2-8: corpo (maiúsculas com 7, minúsculas com x-height 5 a
# partir da linha 4); 9-10: descendentes. Linha de base após a linha 8.
# ======================================================================
CAPS = {
    "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#", "B": "####.|#...#|#...#|####.|#...#|#...#|####.",
    "C": ".###.|#...#|#....|#....|#....|#...#|.###.", "D": "####.|#...#|#...#|#...#|#...#|#...#|####.",
    "E": "#####|#....|#....|####.|#....|#....|#####", "F": "#####|#....|#....|####.|#....|#....|#....",
    "G": ".###.|#...#|#....|#.###|#...#|#...#|.####", "H": "#...#|#...#|#...#|#####|#...#|#...#|#...#",
    "I": "###|.#.|.#.|.#.|.#.|.#.|###", "J": "...#|...#|...#|...#|#..#|#..#|.##.",
    "K": "#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#", "L": "#....|#....|#....|#....|#....|#....|#####",
    "M": "#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#", "N": "#...#|##..#|#.#.#|#..##|#...#|#...#|#...#",
    "O": ".###.|#...#|#...#|#...#|#...#|#...#|.###.", "P": "####.|#...#|#...#|####.|#....|#....|#....",
    "Q": ".###.|#...#|#...#|#...#|#.#.#|#..#.|.##.#", "R": "####.|#...#|#...#|####.|#.#..|#..#.|#...#",
    "S": ".####|#....|#....|.###.|....#|....#|####.", "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..",
    "U": "#...#|#...#|#...#|#...#|#...#|#...#|.###.", "V": "#...#|#...#|#...#|#...#|#...#|.#.#.|..#..",
    "W": "#...#|#...#|#...#|#.#.#|#.#.#|##.##|#...#", "X": "#...#|#...#|.#.#.|..#..|.#.#.|#...#|#...#",
    "Y": "#...#|#...#|.#.#.|..#..|..#..|..#..|..#..", "Z": "#####|....#|...#.|..#..|.#...|#....|#####",
    "0": ".###.|#...#|#..##|#.#.#|##..#|#...#|.###.", "1": "..#..|.##..|..#..|..#..|..#..|..#..|.###.",
    "2": ".###.|#...#|....#|...#.|..#..|.#...|#####", "3": "####.|....#|....#|.###.|....#|....#|####.",
    "4": "...#.|..##.|.#.#.|#..#.|#####|...#.|...#.", "5": "#####|#....|####.|....#|....#|#...#|.###.",
    "6": ".###.|#....|#....|####.|#...#|#...#|.###.", "7": "#####|....#|...#.|..#..|.#...|.#...|.#...",
    "8": ".###.|#...#|#...#|.###.|#...#|#...#|.###.", "9": ".###.|#...#|#...#|.####|....#|....#|.###.",
    " ": "...|...|...|...|...|...|...", "!": "#|#|#|#|#|.|#", '"': "#.#|#.#|...|...|...|...|...",
    "#": ".#.#.|.#.#.|#####|.#.#.|#####|.#.#.|.#.#.", "$": "..#..|.####|#.#..|.###.|..#.#|####.|..#..",
    "%": "##..#|##..#|...#.|..#..|.#...|#..##|#..##", "&": ".##..|#..#.|#.#..|.#...|#.#.#|#..#.|.##.#",
    "'": "#|#|.|.|.|.|.", "(": ".#|#.|#.|#.|#.|#.|.#", ")": "#.|.#|.#|.#|.#|.#|#.",
    "*": ".....|#.#.#|.###.|#####|.###.|#.#.#|.....", "+": ".....|..#..|..#..|#####|..#..|..#..|.....",
    "-": "....|....|....|####|....|....|....", ".": ".|.|.|.|.|.|#", "/": "....#|....#|...#.|..#..|.#...|#....|#....",
    ":": ".|.|.|#|.|.|#", "<": "...#|..#.|.#..|#...|.#..|..#.|...#", "=": "....|....|####|....|####|....|....",
    ">": "#...|.#..|..#.|...#|..#.|.#..|#...", "?": ".###.|#...#|....#|...#.|..#..|.....|..#..",
    "@": ".###.|#...#|#.###|#.#.#|#.##.|#....|.###.", "[": "##|#.|#.|#.|#.|#.|##",
    "\\": "#....|#....|.#...|..#..|...#.|....#|....#", "]": "##|.#|.#|.#|.#|.#|##",
    "^": ".#.|#.#|...|...|...|...|...", "`": "#.|.#|..|..|..|..|..",
    "{": "..#|.#.|.#.|#..|.#.|.#.|..#", "|": "#|#|#|#|#|#|#", "}": "#..|.#.|.#.|..#|.#.|.#.|#..",
    "~": "....|....|.#.#|#.#.|....|....|....", "»": "....|....|#.#.|.#.#|#.#.|....|....",
    "•": "..|..|..|##|##|..|..", "–": ".....|.....|.....|#####|.....|.....|.....",
    "…": ".....|.....|.....|.....|.....|.....|#.#.#",
}
# Minúsculas e sinais com descendente: 9 linhas (a partir da linha 2 da célula).
LOWER = {
    "a": ".....|.....|.###.|....#|.####|#...#|.####|.....|.....", "b": "#....|#....|####.|#...#|#...#|#...#|####.|.....|.....",
    "c": ".....|.....|.####|#....|#....|#....|.####|.....|.....", "d": "....#|....#|.####|#...#|#...#|#...#|.####|.....|.....",
    "e": ".....|.....|.###.|#...#|#####|#....|.###.|.....|.....", "f": "..##|.#..|.#..|###.|.#..|.#..|.#..|....|....",
    "g": ".....|.....|.####|#...#|#...#|#...#|.####|....#|.###.", "h": "#....|#....|####.|#...#|#...#|#...#|#...#|.....|.....",
    "i": "#|.|#|#|#|#|#|.|.", "j": ".#|..|.#|.#|.#|.#|.#|.#|#.",
    "k": "#...|#...|#..#|#.#.|##..|#.#.|#..#|....|....", "l": "#|#|#|#|#|#|#|.|.",
    "m": ".....|.....|##.#.|#.#.#|#.#.#|#.#.#|#.#.#|.....|.....", "n": ".....|.....|####.|#...#|#...#|#...#|#...#|.....|.....",
    "o": ".....|.....|.###.|#...#|#...#|#...#|.###.|.....|.....", "p": ".....|.....|####.|#...#|#...#|#...#|####.|#....|#....",
    "q": ".....|.....|.####|#...#|#...#|#...#|.####|....#|....#", "r": "....|....|#.##|##..|#...|#...|#...|....|....",
    "s": ".....|.....|.####|#....|.###.|....#|####.|.....|.....", "t": ".#..|.#..|###.|.#..|.#..|.#..|..##|....|....",
    "u": ".....|.....|#...#|#...#|#...#|#...#|.####|.....|.....", "v": ".....|.....|#...#|#...#|#...#|.#.#.|..#..|.....|.....",
    "w": ".....|.....|#...#|#...#|#.#.#|#.#.#|.#.#.|.....|.....", "x": ".....|.....|#...#|.#.#.|..#..|.#.#.|#...#|.....|.....",
    "y": ".....|.....|#...#|#...#|#...#|#...#|.####|....#|.###.", "z": ".....|.....|#####|...#.|..#..|.#...|#####|.....|.....",
    ",": ".|.|.|.|.|.|#|#|.", ";": ".|.|.|#|.|.|#|#|.", "_": ".....|.....|.....|.....|.....|.....|.....|#####|.....",
}
ACCENTS = {"acute": "..#|.#.", "grave": "#..|.#.", "circ": ".#.|#.#", "tilde": ".#.#|#.#.", "diaer": "#.#|..."}
COMPOSED = {
    "á": ("a", "acute"), "à": ("a", "grave"), "â": ("a", "circ"), "ã": ("a", "tilde"), "ä": ("a", "diaer"),
    "é": ("e", "acute"), "è": ("e", "grave"), "ê": ("e", "circ"), "ë": ("e", "diaer"),
    "í": ("ı", "acute"), "ì": ("ı", "grave"), "î": ("ı", "circ"), "ï": ("ı", "diaer"),
    "ó": ("o", "acute"), "ò": ("o", "grave"), "ô": ("o", "circ"), "õ": ("o", "tilde"), "ö": ("o", "diaer"),
    "ú": ("u", "acute"), "ù": ("u", "grave"), "û": ("u", "circ"), "ü": ("u", "diaer"), "ñ": ("n", "tilde"),
    "Á": ("A", "acute"), "À": ("A", "grave"), "Â": ("A", "circ"), "Ã": ("A", "tilde"), "É": ("E", "acute"),
    "Ê": ("E", "circ"), "Í": ("I", "acute"), "Ó": ("O", "acute"), "Ô": ("O", "circ"), "Õ": ("O", "tilde"),
    "Ú": ("U", "acute"), "Ñ": ("N", "tilde"),
}


def glyph_rows(char):
    """Devolve as 11 linhas do glifo como listas de 0/1."""
    if char == "ı":  # i sem pingo, base dos acentos
        body = ".|.|#|#|#|#|#|.|."
    elif char in LOWER:
        body = LOWER[char]
    else:
        body = CAPS[char] + "|" + "|".join(["." * len(CAPS[char].split("|")[0])] * 2)
    rows = body.split("|")
    width = len(rows[0])
    assert all(len(r) == width for r in rows) and len(rows) == 9, (char, rows)
    return [[0] * width, [0] * width] + [[1 if c == "#" else 0 for c in r] for r in rows]


def compose(base, accent_name, lower):
    rows = glyph_rows(base)
    accent = [[1 if c == "#" else 0 for c in r] for r in ACCENTS[accent_name].split("|")]
    width = max(len(rows[0]), len(accent[0]))
    def pad(r, w, off):
        return [0] * off + r + [0] * (w - off - len(r))
    base_off = (width - len(rows[0])) // 2
    rows = [pad(r, width, base_off) for r in rows]
    acc_off = (width - len(accent[0])) // 2
    top = 2 if lower else 0  # minúsculas: acento na zona das ascendentes
    for i, r in enumerate(accent):
        rows[top + i] = [a or b for a, b in zip(rows[top + i], pad(r, width, acc_off))]
    return rows


def all_glyphs():
    glyphs = {}
    for ch in list(CAPS) + list(LOWER):
        glyphs[ch] = glyph_rows(ch)
    for ch, (base, accent) in COMPOSED.items():
        glyphs[ch] = compose(base, accent, base.islower() or base == "ı")
    for ch, base in (("ç", "c"), ("Ç", "C")):
        rows = [r[:] for r in glyph_rows(base)]
        mid = len(rows[0]) // 2
        rows[9][mid] = 1
        rows[10][mid - 1] = 1
        glyphs[ch] = rows
    return glyphs


def write_font(glyphs, scale, name, face):
    cell_h = 11 * scale
    sheet = Image.new("RGBA", (256 * scale, 256 * scale), (0, 0, 0, 0))
    px = sheet.load()
    x, y, lines = 1, 1, []
    for ch in sorted(glyphs, key=ord):
        rows = glyphs[ch]
        w = len(rows[0]) * scale
        if x + w + 1 > sheet.width:
            x, y = 1, y + cell_h + 1
        for ry, row in enumerate(rows):
            for rx, on in enumerate(row):
                if on:
                    for sy in range(scale):
                        for sx in range(scale):
                            px[x + rx * scale + sx, y + ry * scale + sy] = (255, 255, 255, 255)
        lines.append(f"char id={ord(ch)} x={x} y={y} width={w} height={cell_h} xoffset=0 yoffset=0 xadvance={w + scale} page=0 chnl=15")
        x += w + 1
    sheet.save(os.path.join(OUT, name + ".png"))
    fnt = [
        f'info face="{face}" size={11 * scale} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
        f"common lineHeight={12 * scale} base={9 * scale} scaleW={sheet.width} scaleH={sheet.height} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(lines)}",
    ] + lines
    with open(os.path.join(OUT, name + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(fnt) + "\n")


# ======================================================================
# Cenário
# ======================================================================
def wall_tile():
    img = Image.new("RGBA", (32, 32), rgba("wood1"))
    d = ImageDraw.Draw(img)
    for i, x in enumerate(range(0, 32, 8)):
        d.rectangle((x, 0, x + 7, 31), fill=rgba("wood1" if i % 2 else "wood0"))
        d.line((x, 0, x, 31), fill=rgba("void"))
    speckle(img, (0, 0, 32, 32), ["wood2", "void"], 23, 7)
    save(img, "wall.png")


def desk_tile():
    img = Image.new("RGBA", (64, 32), rgba("wood3"))
    d = ImageDraw.Draw(img)
    for y in (0, 16):
        d.line((0, y, 63, y), fill=rgba("wood1"))
        d.line((0, y + 1, 63, y + 1), fill=rgba("wood4"))
    for (x, y, l) in ((5, 6, 18), (30, 10, 22), (44, 4, 14), (10, 22, 26), (40, 26, 20), (2, 13, 9)):
        d.line((x, y, x + l, y), fill=rgba("wood2"))
    d.line((47, 17, 47, 31), fill=rgba("wood1"))
    d.line((21, 2, 21, 15), fill=rgba("wood1"))
    save(img, "desk.png")


def counter_tile():
    img = Image.new("RGBA", (16, 8), rgba("wood4"))
    d = ImageDraw.Draw(img)
    d.line((0, 0, 15, 0), fill=rgba("wood5"))
    d.line((0, 6, 15, 6), fill=rgba("wood2"))
    d.line((0, 7, 15, 7), fill=rgba("void"))
    save(img, "counter.png")


def window_back():
    w, h = 212, 106
    img = Image.new("RGBA", (w, h), rgba("night0"))
    px = img.load()
    bands = ["night0", "night1", "night2", "night3"]
    for y in range(h):
        t = y / h * (len(bands) - 1)
        i = min(int(t), len(bands) - 2)
        frac = t - i
        for x in range(w):
            # Pontilhado ordenado 2x2 entre faixas: gradiente em pixel art.
            threshold = ((x % 2) * 2 + (y % 2)) / 4
            px[x, y] = rgba(bands[i + 1] if frac > threshold + 0.1 else bands[i])
    d = ImageDraw.Draw(img)
    d.ellipse((160, 10, 176, 26), fill=rgba("parch0"))
    d.ellipse((164, 12, 178, 26), fill=rgba("night0"))
    for (sx, sy) in ((20, 8), (48, 16), (90, 6), (120, 20), (140, 9), (195, 18), (70, 28)):
        px[sx, sy] = rgba("lamp2")
    skyline = [(0, 70, 26), (24, 58, 18), (40, 66, 30), (68, 48, 14), (80, 62, 34), (112, 54, 20), (130, 68, 26), (154, 44, 16), (168, 60, 44)]
    for x0, top, width in skyline:
        d.rectangle((x0, top, x0 + width, h), fill=rgba("city"))
        d.polygon([(x0, top), (x0 + width // 2, top - 8), (x0 + width, top)], fill=rgba("city"))
        for wx in range(x0 + 3, x0 + width - 2, 5):
            for wy in range(top + 4, h - 6, 7):
                if (wx * 7 + wy * 3) % 5 == 0:
                    d.rectangle((wx, wy, wx + 1, wy + 2), fill=rgba("lamp"))
    d.rectangle((0, h - 8, w, h), fill=rgba("void"))
    save(img, "window_back.png")


def window_front():
    w, h = 224, 118
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), fill=rgba("wood2"))
    d.rectangle((6, 6, w - 7, h - 7), fill=(0, 0, 0, 0))
    d.line((0, 0, w - 1, 0), fill=rgba("wood4"))
    d.line((0, 0, 0, h - 1), fill=rgba("wood4"))
    d.rectangle((0, h - 6, w - 1, h - 1), fill=rgba("wood3"))
    d.line((0, h - 6, w - 1, h - 6), fill=rgba("wood5"))
    d.rectangle((5, 5, w - 6, h - 6), outline=rgba("void"))
    # Grades nas laterais; o meio fica livre para o rosto do cliente.
    for bx in (26, 62, 158, 194):
        d.rectangle((bx, 6, bx + 2, h - 8), fill=rgba("iron1"))
        d.line((bx, 6, bx, h - 8), fill=rgba("iron2"))
        d.line((bx + 3, 6, bx + 3, h - 8), fill=rgba("iron0"))
    d.rectangle((6, 34, w - 7, 36), fill=rgba("iron1"))
    d.line((6, 34, w - 7, 34), fill=rgba("iron2"))
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        img.putpixel((cx, cy), rgba("brass2"))
    save(img, "window_front.png")


# ======================================================================
# Personagens
# ======================================================================
def goblin():
    img = new(72, 84)
    d = ImageDraw.Draw(img)
    d.polygon([(6, 83), (14, 66), (28, 60), (44, 60), (58, 66), (66, 83)], fill=rgba("cloak1"))
    d.polygon([(40, 60), (58, 66), (66, 83), (44, 83)], fill=rgba("cloak0"))
    d.polygon([(24, 60), (36, 70), (48, 60)], fill=rgba("cloak2"))
    d.rectangle((30, 52, 42, 62), fill=rgba("green1"))
    for side in (1, -1):
        cx = 36
        ear = [(cx - side * 18, 30), (cx - side * 36, 12), (cx - side * 32, 24), (cx - side * 20, 40)]
        d.polygon(ear, fill=rgba("green2"))
        inner = [(cx - side * 20, 30), (cx - side * 32, 17), (cx - side * 29, 25), (cx - side * 21, 35)]
        d.polygon(inner, fill=rgba("green0"))
    d.ellipse((14, 14, 58, 58), fill=rgba("green1"))
    d.ellipse((13, 12, 55, 54), fill=rgba("green2"))
    d.ellipse((21, 17, 33, 25), fill=rgba("green3"))
    d.line((22, 26, 31, 24), fill=rgba("green0"), width=2)
    d.line((40, 24, 49, 26), fill=rgba("green0"), width=2)
    d.ellipse((22, 28, 32, 38), fill=rgba("white"))
    d.ellipse((40, 28, 50, 38), fill=rgba("white"))
    d.rectangle((26, 31, 29, 35), fill=rgba("void"))
    d.rectangle((43, 31, 46, 35), fill=rgba("void"))
    d.point([(27, 32), (44, 32)], fill=rgba("white"))
    d.rectangle((34, 36, 37, 40), fill=rgba("green1"))
    d.ellipse((25, 41, 47, 53), fill=rgba("void"))
    d.ellipse((31, 46, 42, 54), fill=rgba("tongue"))
    d.rectangle((28, 42, 30, 44), fill=rgba("white"))
    d.rectangle((41, 42, 43, 44), fill=rgba("white"))
    outline(img)
    d = ImageDraw.Draw(img)
    d.ellipse((62, 28, 68, 34), outline=rgba("brass2"))
    for hx in (8, 50):
        d.ellipse((hx, 76, hx + 14, 84), fill=rgba("green2"))
        d.line((hx + 4, 78, hx + 4, 83), fill=rgba("green0"))
        d.line((hx + 9, 78, hx + 9, 83), fill=rgba("green0"))
    save(img, "portrait_goblin.png")


def silhouette():
    """Cliente genérico: capuz claro, tingido pela cor de cada encomenda."""
    img = new(72, 84)
    d = ImageDraw.Draw(img)
    d.polygon([(4, 83), (12, 62), (26, 54), (46, 54), (60, 62), (68, 83)], fill=rgba("grey1"))
    d.polygon([(40, 54), (60, 62), (68, 83), (46, 83)], fill=rgba("grey0"))
    d.ellipse((14, 10, 58, 62), fill=rgba("grey2"))
    d.polygon([(36, 6), (22, 20), (50, 20)], fill=rgba("grey2"))
    d.ellipse((22, 22, 50, 58), fill=rgba("grey0"))
    d.ellipse((25, 30, 47, 56), fill=rgba("void"))
    d.point([(30, 40), (31, 40), (41, 40), (42, 40)], fill=rgba("grey2"))
    outline(img)
    save(img, "portrait_hooded.png")


# ======================================================================
# Papéis, placas e objetos
# ======================================================================
def nine(name, size, border, fill, edge=None, inner=None, speck=None, corners=None):
    img = Image.new("RGBA", (size, size), rgba(fill))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, size - 1, size - 1), outline=rgba(border))
    if edge:
        d.rectangle((1, 1, size - 2, size - 2), outline=rgba(edge))
    if inner:
        d.rectangle((2, 2, size - 3, size - 3), outline=rgba(inner))
    if speck:
        speckle(img, (3, 3, size - 3, size - 3), speck, 29, size)
    if corners:
        for cx, cy in ((2, 2), (size - 3, 2), (2, size - 3), (size - 3, size - 3)):
            img.putpixel((cx, cy), rgba(corners))
    # Cantos gastos: um pixel transparente em cada canto.
    for cx, cy in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        img.putpixel((cx, cy), (0, 0, 0, 0))
    save(img, name)


def book():
    img = Image.new("RGBA", (24, 24), rgba("parch0"))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 23, 23), fill=rgba("leather1"))
    d.rectangle((0, 0, 23, 0), fill=rgba("leather2"))
    d.rectangle((3, 3, 20, 20), fill=rgba("parch0"))
    d.rectangle((3, 3, 20, 20), outline=rgba("parch2"))
    d.rectangle((0, 0, 23, 23), outline=rgba("leather0"))
    for cx, cy in ((1, 1), (22, 1), (1, 22), (22, 22)):
        img.putpixel((cx, cy), rgba("brass2"))
    save(img, "book.png")


def stamp_box():
    img = new(12, 12)
    px = img.load()
    for i in range(12):
        if i % 4 < 2:
            for x, y in ((i, 0), (i, 11), (0, i), (11, i)):
                px[x, y] = rgba("parch3")
    save(img, "stamp_box.png")


def stamp(name, body, body_dark, body_light):
    img = new(40, 46)
    d = ImageDraw.Draw(img)
    d.ellipse((13, 0, 26, 12), fill=rgba("wood4"))
    d.ellipse((15, 1, 21, 6), fill=rgba("wood5"))
    d.rectangle((17, 11, 22, 19), fill=rgba("wood3"))
    d.rectangle((6, 19, 33, 35), fill=rgba(body))
    d.rectangle((6, 19, 9, 35), fill=rgba(body_light))
    d.rectangle((29, 19, 33, 35), fill=rgba(body_dark))
    d.rectangle((2, 36, 37, 44), fill=rgba("brass1"))
    d.line((2, 36, 37, 36), fill=rgba("brass3"))
    d.line((2, 44, 37, 44), fill=rgba("brass0"))
    outline(img)
    save(img, name)


def bell():
    img = new(26, 24)
    d = ImageDraw.Draw(img)
    d.rectangle((11, 0, 14, 3), fill=rgba("brass1"))
    d.polygon([(5, 18), (7, 8), (12, 3), (13, 3), (18, 8), (20, 18)], fill=rgba("brass2"))
    d.polygon([(8, 16), (9, 8), (12, 5)], fill=rgba("brass3"))
    d.polygon([(16, 8), (20, 18), (17, 18)], fill=rgba("brass1"))
    d.rectangle((2, 18, 23, 20), fill=rgba("brass1"))
    d.line((2, 18, 23, 18), fill=rgba("brass3"))
    d.ellipse((11, 20, 14, 23), fill=rgba("brass0"))
    outline(img)
    save(img, "bell.png")


def candle():
    img = new(14, 44)
    d = ImageDraw.Draw(img)
    d.polygon([(7, 0), (4, 6), (5, 10), (9, 10), (10, 6)], fill=rgba("brass3"))
    d.polygon([(7, 3), (6, 7), (7, 9), (8, 7)], fill=rgba("white"))
    d.line((7, 10, 7, 12), fill=rgba("void"))
    d.rectangle((4, 12, 10, 37), fill=rgba("parch0"))
    d.rectangle((9, 12, 10, 37), fill=rgba("parch1"))
    d.rectangle((4, 12, 5, 18), fill=rgba("white"))
    d.rectangle((0, 38, 13, 43), fill=rgba("brass1"))
    d.line((0, 38, 13, 38), fill=rgba("brass3"))
    outline(img)
    save(img, "candle.png")


def bubble_tail():
    img = new(8, 10)
    d = ImageDraw.Draw(img)
    d.polygon([(7, 0), (0, 5), (7, 9)], fill=rgba("note"))
    d.line((7, 0, 0, 5), fill=rgba("ink"))
    d.line((0, 5, 7, 9), fill=rgba("ink"))
    save(img, "bubble_tail.png")


if __name__ == "__main__":
    glyphs = all_glyphs()
    write_font(glyphs, 1, "pixel_font", "Atelier Pixel")
    write_font(glyphs, 2, "pixel_font_big", "Atelier Pixel Big")
    wall_tile(); desk_tile(); counter_tile(); window_back(); window_front()
    goblin(); silhouette()
    nine("parchment.png", 24, "parch3", "parch0", edge="parch2", inner="parch1", speck=["parch1", "parch2"])
    nine("note.png", 16, "note_edge", "note", speck=["parch0"])
    nine("sign.png", 16, "void", "wood3", edge="wood5", corners="brass2")
    nine("bubble.png", 16, "ink", "note")
    book(); stamp_box(); bell(); candle(); bubble_tail()
    stamp("stamp_approve.png", "green2", "green0", "green3")
    stamp("stamp_reject.png", "red1", "red0", "red2")
    print("pixel art written to", OUT, "-", len(glyphs), "glyphs")
