"""Arte provisória do balcão em pixel art (M6, recomposto no M8).

Gera em art/pixel/ os PNGs do balcão e fontes bitmap próprias (BMFont): a
normal, a grande (marca do carimbo), a de título e a miúda de versaletes.
Tudo é placeholder original, desenhado por código para um balcão de 640x360
com escala inteira; troque os arquivos quando houver arte de verdade.
O fundo (backdrop.png) já vem com a luz pintada: vela quente à esquerda da
janela, luar frio no balcão sob a janela e madeira mais escura nas bordas.
As posições da vela e da janela abaixo têm de bater com scenes/game/Desk.tscn.
Rodar: python tools/pixel_art/generate_pixel_art.py
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
    # Papel do pedido: o creme mais claro da cena (é o foco).
    "cream0": (246, 232, 196), "cream1": (236, 218, 176), "cream2": (214, 190, 142),
    "ribbon0": (40, 46, 78), "ribbon1": (62, 70, 112),
}
# Significados reservados (não usar como enfeite): vermelho = discrepância e
# recusa, verde = aprovado, roxo = requisito mágico, dourado = interação.

# Layout do balcão (px do balcão, 640x360); tem de bater com Desk.tscn.
COUNTER_Y = 128
WINDOW = (208, 6, 224, 118)
CANDLE_FLAME = (191, 88)


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


# Versaletes miúdos (5 linhas de corpo) para metadados: cabeçalhos de papel,
# rótulos de seção, notas. Minúsculas usam o mesmo desenho das maiúsculas.
TINY = {
    "A": ".#.|#.#|###|#.#|#.#", "B": "##.|#.#|##.|#.#|##.", "C": ".##|#..|#..|#..|.##", "D": "##.|#.#|#.#|#.#|##.",
    "E": "###|#..|##.|#..|###", "F": "###|#..|##.|#..|#..", "G": ".##|#..|#.#|#.#|.##", "H": "#.#|#.#|###|#.#|#.#",
    "I": "###|.#.|.#.|.#.|###", "J": "..#|..#|..#|#.#|.#.", "K": "#.#|#.#|##.|#.#|#.#", "L": "#..|#..|#..|#..|###",
    "M": "#...#|##.##|#.#.#|#...#|#...#", "N": "#..#|##.#|#.##|#..#|#..#", "O": ".#.|#.#|#.#|#.#|.#.",
    "P": "##.|#.#|##.|#..|#..", "Q": ".#.|#.#|#.#|##.|.##", "R": "##.|#.#|##.|#.#|#.#", "S": ".##|#..|.#.|..#|##.",
    "T": "###|.#.|.#.|.#.|.#.", "U": "#.#|#.#|#.#|#.#|###", "V": "#.#|#.#|#.#|#.#|.#.", "W": "#...#|#...#|#.#.#|##.##|#...#",
    "X": "#.#|#.#|.#.|#.#|#.#", "Y": "#.#|#.#|.#.|.#.|.#.", "Z": "###|..#|.#.|#..|###",
    "0": "###|#.#|#.#|#.#|###", "1": ".#.|##.|.#.|.#.|###", "2": "##.|..#|.#.|#..|###", "3": "##.|..#|.#.|..#|##.",
    "4": "#.#|#.#|###|..#|..#", "5": "###|#..|##.|..#|##.", "6": ".##|#..|###|#.#|###", "7": "###|..#|.#.|.#.|.#.",
    "8": "###|#.#|###|#.#|###", "9": "###|#.#|###|..#|##.", " ": "..|..|..|..|..", ".": ".|.|.|.|#", ":": ".|#|.|#|.",
    "-": "..|..|##|..|..", "'": "#|#|.|.|.", "!": "#|#|#|.|#", "?": "##.|..#|.#.|...|.#.", "(": ".#|#.|#.|#.|.#",
    ")": "#.|.#|.#|.#|#.", "/": "..#|..#|.#.|#..|#..", "%": "#.#|..#|.#.|#..|#.#", "»": "....|#.#.|.#.#|#.#.|....",
    "–": "...|...|###|...|...", "#": "#.#|###|#.#|###|#.#", "+": "...|.#.|###|.#.|...",
}
TINY_ACCENTS = {"acute": "..#|.#.", "grave": "#..|.#.", "circ": ".#.|#.#", "tilde": ".##|##.", "diaer": "#.#|..."}


def tiny_glyphs():
    """Células de 8 linhas: 2 de acento, 5 de corpo, 1 para vírgula e cedilha."""
    def cell(body):
        rows = body.split("|")
        w = len(rows[0])
        assert all(len(r) == w for r in rows) and len(rows) == 5, rows
        return [[0] * w, [0] * w] + [[1 if c == "#" else 0 for c in r] for r in rows] + [[0] * w]
    glyphs = {ch: cell(body) for ch, body in TINY.items()}
    glyphs[","] = [[0], [0], [0], [0], [0], [0], [1], [1]]
    for ch, (base, accent) in COMPOSED.items():
        base = base.upper() if base != "ı" else "I"
        rows = [r[:] for r in glyphs[base]]
        acc = [[1 if c == "#" else 0 for c in r] for r in TINY_ACCENTS[accent].split("|")]
        off = max(0, (len(rows[0]) - len(acc[0])) // 2)
        for i, r in enumerate(acc):
            for j, on in enumerate(r):
                if on and off + j < len(rows[0]):
                    rows[i][off + j] = 1
        glyphs[ch.upper()] = rows
        glyphs[ch] = rows
    for ch in ("Ç", "ç"):
        rows = [r[:] for r in glyphs["C"]]
        rows[7][1] = 1
        glyphs[ch] = rows
    for ch in list(glyphs):
        if ch.isalpha() and ch.lower() not in glyphs:
            glyphs[ch.lower()] = glyphs[ch]
    return glyphs


def title_glyphs(glyphs):
    """Fonte de título: o desenho normal mais alto (linhas 3 e 6 da célula
    repetidas, maiúsculas com 9 px) e em negrito: cada pixel ganha o vizinho
    da direita, menos quando isso fecharia o vão de 1 px até o próximo traço
    (m, w, e continuam legíveis). Célula de 13 linhas, base após a linha 10."""
    out = {}
    for ch, rows in glyphs.items():
        tall = []
        for i, r in enumerate(rows):
            tall.append(r[:])
            if i in (3, 6):
                tall.append(r[:])
        bold = []
        for r in tall:
            b = r[:] + [0]
            for x, on in enumerate(r):
                if on and not (x + 2 < len(r) and not r[x + 1] and r[x + 2]):
                    b[x + 1] = 1
            bold.append(b)
        out[ch] = bold
    return out


def write_font(glyphs, scale, name, face, cell=11, line=12, base=9):
    cell_h = cell * scale
    sheet = Image.new("RGBA", (256 * scale, 256 * scale), (0, 0, 0, 0))
    px = sheet.load()
    x, y, lines = 1, 1, []
    for ch in sorted(glyphs, key=ord):
        rows = glyphs[ch]
        assert len(rows) == cell, (name, ch, len(rows))
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
        f'info face="{face}" size={cell * scale} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
        f"common lineHeight={line * scale} base={base * scale} scaleW={sheet.width} scaleH={sheet.height} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(lines)}",
    ] + lines
    with open(os.path.join(OUT, name + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(fnt) + "\n")


# ======================================================================
# Cenário
# ======================================================================
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
WALL_RAMP = ["void", "wood0", "wood1", "wood2", "wood3"]
DESK_RAMP = ["void", "wood0", "wood1", "wood2", "wood3", "wood4", "wood5"]


def light(x, y):
    """Deslocamento de tom (em degraus da rampa) pela luz da cena."""
    import math
    dx, dy = (x - 320) / 320, (y - 205) / 190
    edge = max(0.0, math.hypot(dx, dy) - 0.42) / 0.7
    shift = -1.6 * min(edge, 1.3)
    fx, fy = CANDLE_FLAME
    d = math.hypot(x - fx, (y - fy) * 1.15)
    shift += 1.8 * max(0.0, 1 - d / 210) ** 1.4
    # Poça de luz sobre o centro da mesa, onde fica o pedido.
    d = math.hypot((x - 318) / 1.4, y - 250)
    shift += 0.55 * max(0.0, 1 - d / 150)
    return shift


def lit(ramp, index, x, y):
    t = BAYER[y % 4][x % 4] / 16
    i = int(index + light(x, y) + t)
    return rgba(ramp[max(0, min(len(ramp) - 1, i))])


def backdrop():
    """Fundo inteiro do balcão (parede, beirada e tampo) com a luz pintada."""
    w, h = 640, 360
    img = Image.new("RGBA", (w, h))
    px = img.load()
    n = 7
    for y in range(h):
        for x in range(w):
            n = (n * 1103515245 + 12345) & 0x7FFFFFFF
            if y < COUNTER_Y:
                # Parede: tábuas verticais de 8 px com juntas escuras.
                board = x // 8
                index = 2 if board % 2 else 1.6
                if x % 8 == 0:
                    index = 0.6
                elif n % 23 == 0:
                    index += 1
                px[x, y] = lit(WALL_RAMP, index, x, y)
            elif y < COUNTER_Y + 8:
                # Beirada do balcão; sob a janela, o luar esfria a quina.
                row = y - COUNTER_Y
                index = [5.6, 5, 5, 4.6, 4.6, 4.2, 3, 0][row]
                color = lit(DESK_RAMP, index, x, y)
                if row == 0 and WINDOW[0] + 4 <= x < WINDOW[0] + WINDOW[2] - 4:
                    color = rgba("night3" if (x + y) % 3 else "grey1")
                px[x, y] = color
            else:
                # Tampo: tábuas horizontais de 16 px, veios e emendas.
                dy = (y - COUNTER_Y - 8) % 16
                index = 4
                if dy == 0:
                    index = 2
                elif dy == 1:
                    index = 5
                elif (x * 3 + (y // 16) * 37) % 97 < 26 and dy in (6, 11):
                    index = 3.3
                elif n % 31 == 0:
                    index = 3.5
                if (x + (y // 16) * 53) % 149 == 0 and dy > 1:
                    index = 2.2
                px[x, y] = lit(DESK_RAMP, index, x, y)
    save(img, "backdrop.png")


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
    # Travessa alta: os retratos (92x92, de y 20 até o balcão) ficam abaixo dela.
    d.rectangle((6, 16, w - 7, 18), fill=rgba("iron1"))
    d.line((6, 16, w - 7, 16), fill=rgba("iron2"))
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        img.putpixel((cx, cy), rgba("brass2"))
    save(img, "window_front.png")


# ======================================================================
# Personagens
# ======================================================================
def silhouette():
    """Cliente genérico: capuz claro, tingido pela cor de cada encomenda. Mesma
    tela dos retratos (92x92), com o busto encostado embaixo."""
    img = new(92, 92)
    d = ImageDraw.Draw(img)
    ox, oy = 10, 8
    def at(points):
        return [(x + ox, y + oy) for x, y in points]
    d.polygon(at([(4, 83), (12, 62), (26, 54), (46, 54), (60, 62), (68, 83)]), fill=rgba("grey1"))
    d.polygon(at([(40, 54), (60, 62), (68, 83), (46, 83)]), fill=rgba("grey0"))
    d.ellipse((14 + ox, 10 + oy, 58 + ox, 62 + oy), fill=rgba("grey2"))
    d.polygon(at([(36, 6), (22, 20), (50, 20)]), fill=rgba("grey2"))
    d.ellipse((22 + ox, 22 + oy, 50 + ox, 58 + oy), fill=rgba("grey0"))
    d.ellipse((25 + ox, 30 + oy, 47 + ox, 56 + oy), fill=rgba("void"))
    d.point(at([(30, 40), (31, 40), (41, 40), (42, 40)]), fill=rgba("grey2"))
    outline(img)
    save(img, "portrait_hooded.png")


# ======================================================================
# Papéis, placas e objetos
# ======================================================================
def shadow(img, box, alpha=96):
    """Sombra de 2 px (baixo e direita) em pixel art: preto translúcido."""
    d = ImageDraw.Draw(img)
    d.rectangle(box, fill=(12, 6, 8, alpha))


def paper_9(name, size, fill, edge, inner, speck, curl=False, notches=True):
    """Papel 9-slice com sombra de 2 px, borda irregular e, se curl, canto
    inferior direito dobrado. Margens de textura: 8 (esq/topo), 10 (dir/base)."""
    img = new(size, size)
    shadow(img, (2, 2, size - 1, size - 1))
    d = ImageDraw.Draw(img)
    body = (0, 0, size - 3, size - 3)
    d.rectangle(body, fill=rgba(fill))
    d.rectangle(body, outline=rgba(edge))
    d.rectangle((1, 1, size - 4, size - 4), outline=rgba(inner))
    px = img.load()
    if notches:
        # Borda gasta: alguns pixels da beirada somem ou clareiam, num padrão
        # que se repete bem quando o 9-slice ladrilha as bordas.
        for i in range(size - 2):
            if i % 7 == 3:
                px[i, 0] = (0, 0, 0, 0)
                px[i, 1] = rgba(edge)
            if i % 9 == 5:
                px[0, i] = (0, 0, 0, 0)
                px[1, i] = rgba(edge)
            if i % 8 == 2:
                px[size - 3, i] = rgba(inner)
    if speck:
        speckle(img, (3, 3, size - 5, size - 5), speck, 31, size)
    if curl:
        # Canto dobrado: triângulo do verso, vinco escuro e sombra embaixo.
        c = size - 3
        for k in range(7):
            for j in range(7 - k):
                px[c - k, c - j] = (0, 0, 0, 0)
        for k in range(7):
            for j in range(k + 1):
                px[c - 6 + j, c - 6 + k - j] = rgba(inner) if j < k else rgba(edge)
        for k in range(7):
            px[c - 6 + k, c - k] = rgba("parch3")
    for cx, cy in ((0, 0), (size - 3, 0), (0, size - 3)):
        px[cx, cy] = (0, 0, 0, 0)
    save(img, name)


def bubble_9():
    img = new(18, 18)
    shadow(img, (2, 2, 17, 17), 80)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 15, 15), fill=rgba("note"), outline=rgba("ink"))
    for cx, cy in ((0, 0), (15, 0), (0, 15), (15, 15)):
        img.putpixel((cx, cy), (0, 0, 0, 0))
    save(img, "bubble.png")


def book_spread():
    """Livro de regras aberto: capa de couro, duas páginas, vinco central,
    fita marcadora e o selo da guilda (enfeite, em tinta apagada)."""
    w, h = 200, 222
    img = new(w, h)
    shadow(img, (3, 4, w - 1, 213))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 2, w - 4, 211), fill=rgba("leather1"), outline=rgba("leather0"))
    d.line((1, 3, w - 5, 3), fill=rgba("leather2"))
    for cx, cy in ((0, 2), (w - 4, 2), (0, 211), (w - 4, 211)):
        img.putpixel((cx, cy), (0, 0, 0, 0))
    # Espessura das folhas embaixo das páginas.
    for i, y in enumerate(range(202, 208)):
        d.line((5 + i // 2, y, w - 9 - i // 2, y), fill=rgba("parch1" if i % 2 == 0 else "parch2"))
    px = img.load()
    seam = 98
    for x in range(4, w - 7):
        # Páginas curvas: sobem nas bordas e descem no vinco.
        dist = abs(x - seam)
        top = 5 + (2 if dist < 8 else 1 if dist < 24 else 0)
        for y in range(top, 202):
            color = "parch1"
            if dist <= 1:
                color = "leather0"
            elif dist < 9:
                t = BAYER[y % 4][x % 4] / 16
                color = "parch3" if dist + t * 3 < 4 else "parch2" if dist + t * 4 < 8 else "parch1"
            elif x < 7 or x > w - 11:
                color = "parch2"
            px[x, y] = rgba(color)
    speckle(img, (8, 8, w - 12, 200), ["parch2"], 41, 11)
    # Florões no pé de cada página.
    for fx in (50, 147):
        for dx, dy in ((-4, 0), (-2, 0), (0, -1), (0, 1), (0, 0), (2, 0), (4, 0), (-1, 0), (1, 0)):
            px[fx + dx, 196 + dy] = rgba("parch3")
    # Selo da guilda, no canto da página direita.
    sx, sy = 180, 186
    d.ellipse((sx - 6, sy - 6, sx + 6, sy + 6), outline=rgba("parch3"))
    for dx, dy in ((0, -3), (0, -2), (0, 2), (0, 3), (-3, 0), (-2, 0), (2, 0), (3, 0), (0, 0), (-1, -1), (1, 1), (1, -1), (-1, 1)):
        px[sx + dx, sy + dy] = rgba("parch3")
    # Fita marcadora saindo por baixo.
    for y in range(196, h):
        for x in range(150, 155):
            px[x, y] = rgba("ribbon1" if x < 153 else "ribbon0")
    px[152, h - 1] = (0, 0, 0, 0)
    px[151, h - 1] = (0, 0, 0, 0)
    px[152, h - 2] = (0, 0, 0, 0)
    save(img, "book_spread.png")


def stamp_box():
    img = new(12, 12)
    px = img.load()
    for i in range(12):
        if i % 4 < 2:
            for x, y in ((i, 0), (i, 11), (0, i), (11, i)):
                px[x, y] = rgba("parch3")
    save(img, "stamp_box.png")


def stamp_body(body, body_dark, body_light, rim="void"):
    """Carimbo de borracha em pé: pegador de madeira, corpo colorido e base de latão."""
    img = new(46, 52)
    d = ImageDraw.Draw(img)
    d.ellipse((16, 0, 29, 12), fill=rgba("wood4"))
    d.ellipse((18, 1, 24, 6), fill=rgba("wood5"))
    d.rectangle((20, 12, 25, 20), fill=rgba("wood3"))
    d.line((20, 12, 20, 20), fill=rgba("wood4"))
    d.rectangle((9, 20, 36, 37), fill=rgba(body))
    d.rectangle((9, 20, 12, 37), fill=rgba(body_light))
    d.rectangle((32, 20, 36, 37), fill=rgba(body_dark))
    d.rectangle((4, 38, 41, 46), fill=rgba("brass1"))
    d.line((4, 38, 41, 38), fill=rgba("brass3"))
    d.line((4, 46, 41, 46), fill=rgba("brass0"))
    d.rectangle((6, 47, 39, 48), fill=rgba("ink"))
    outline(img, rim)
    return img


def stamp(name, body, body_dark, body_light):
    """Três sprites: em repouso (com sombra), erguido no hover (2 px acima,
    contorno de latão) e a cabeça que voa até o papel (sem sombra)."""
    head = stamp_body(body, body_dark, body_light)
    head.save(os.path.join(OUT, name + "_head.png"))
    for suffix, lift, rim in (("", 0, "void"), ("_lift", 2, "brass3")):
        img = new(46, 56)
        d = ImageDraw.Draw(img)
        d.ellipse((3, 48, 45, 55), fill=(12, 6, 8, 110 if lift == 0 else 70))
        img.alpha_composite(stamp_body(body, body_dark, body_light, rim), (0, 2 - lift + 2))
        save(img, name + suffix + ".png")


def ink_pad():
    img = new(22, 13)
    d = ImageDraw.Draw(img)
    d.rectangle((2, 3, 21, 12), fill=(12, 6, 8, 100))
    d.rectangle((0, 1, 19, 10), fill=rgba("brass1"), outline=rgba("brass0"))
    d.line((1, 1, 18, 1), fill=rgba("brass3"))
    d.rectangle((2, 3, 17, 8), fill=rgba("ribbon0"))
    d.line((3, 4, 9, 4), fill=rgba("ribbon1"))
    save(img, "ink_pad.png")


def bell():
    img = new(28, 26)
    d = ImageDraw.Draw(img)
    d.ellipse((3, 20, 27, 25), fill=(12, 6, 8, 100))
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


def small_props():
    """Alfinete do cartão do dia, clipe da nota, ícones e o florão do pedido."""
    pin = new(7, 8)
    d = ImageDraw.Draw(pin)
    d.ellipse((1, 0, 6, 5), fill=rgba("brass2"), outline=rgba("brass0"))
    pin.putpixel((2, 1), rgba("brass3"))
    d.line((3, 6, 3, 7), fill=rgba("iron1"))
    save(pin, "pin.png")
    clip = new(7, 16)
    d = ImageDraw.Draw(clip)
    d.rounded_rectangle((0, 0, 6, 15), radius=3, outline=rgba("iron2"))
    d.rounded_rectangle((2, 3, 4, 12), radius=1, outline=rgba("iron1"))
    save(clip, "clip.png")
    for name, rows, colors in (
        ("icon_coin", ".###.|#+++#|#+#+#|#+++#|.###.", {"#": "brass0", "+": "brass2"}),
        ("icon_star", "..#..|.###.|#####|.###.|.#.#.", {"#": "brass1"}),
        ("icon_queue", "#####|.+++.|..+..|.#+#.|#####", {"#": "wood3", "+": "brass1"}),
    ):
        grid = rows.split("|")
        icon = new(len(grid[0]), len(grid))
        for y, row in enumerate(grid):
            for x, c in enumerate(row):
                if c in colors:
                    icon.putpixel((x, y), rgba(colors[c]))
        save(icon, name + ".png")
    orn = new(64, 5)
    d = ImageDraw.Draw(orn)
    d.line((4, 2, 26, 2), fill=rgba("parch2"))
    d.line((37, 2, 59, 2), fill=rgba("parch2"))
    d.polygon([(32, 0), (34, 2), (32, 4), (30, 2)], fill=rgba("parch3"))
    for x in (28, 36):
        orn.putpixel((x, 2), rgba("parch3"))
    save(orn, "ornament.png")


if __name__ == "__main__":
    glyphs = all_glyphs()
    write_font(glyphs, 1, "pixel_font", "Atelier Pixel")
    write_font(glyphs, 2, "pixel_font_big", "Atelier Pixel Big")
    write_font(title_glyphs(glyphs), 1, "pixel_font_title", "Atelier Pixel Title", cell=13, line=14, base=11)
    tiny = tiny_glyphs()
    write_font(tiny, 1, "pixel_font_tiny", "Atelier Pixel Tiny", cell=8, line=9, base=7)
    backdrop(); window_back(); window_front()
    silhouette()
    paper_9("parchment.png", 32, "cream0", "parch2", "cream1", ["cream1", "cream2"], curl=True)
    paper_9("note.png", 24, "parch0", "parch2", "parch1", ["parch1"])
    paper_9("card.png", 24, "parch0", "parch2", "parch1", ["parch1"], notches=False)
    bubble_9(); book_spread(); stamp_box(); bell(); candle(); bubble_tail(); ink_pad(); small_props()
    stamp("stamp_approve", "green2", "green0", "green3")
    stamp("stamp_reject", "red1", "red0", "red2")
    print("pixel art written to", OUT, "-", len(glyphs), "glyphs,", len(tiny), "tiny glyphs")
