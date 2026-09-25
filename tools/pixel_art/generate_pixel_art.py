"""Arte do balcão desenhada por código (M6, M8).

Gera em art/pixel/ as fontes bitmap próprias (BMFont: a normal, a grande da
marca do carimbo, a de título e a miúda de versaletes), a silhueta genérica
dos clientes sem retrato, o balão de fala e a área tracejada do carimbo.
O resto do balcão (fundo, livro, pedido, nota, carimbos, sino, vela, cartão
do dia) vem dos assets de produção: veja tools/pixel_art/import_desk_art.py.
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


def bubble_9():
    img = new(18, 18)
    shadow(img, (2, 2, 17, 17), 80)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 15, 15), fill=rgba("note"), outline=rgba("ink"))
    for cx, cy in ((0, 0), (15, 0), (0, 15), (15, 15)):
        img.putpixel((cx, cy), (0, 0, 0, 0))
    save(img, "bubble.png")


def stamp_box():
    img = new(12, 12)
    px = img.load()
    for i in range(12):
        if i % 4 < 2:
            for x, y in ((i, 0), (i, 11), (0, i), (11, i)):
                px[x, y] = rgba("parch3")
    save(img, "stamp_box.png")


def bubble_tail():
    img = new(8, 10)
    d = ImageDraw.Draw(img)
    d.polygon([(7, 0), (0, 5), (7, 9)], fill=rgba("note"))
    d.line((7, 0, 0, 5), fill=rgba("ink"))
    d.line((0, 5, 7, 9), fill=rgba("ink"))
    save(img, "bubble_tail.png")


def gear():
    """Engrenagem de latão das configurações (18x18): oito dentes, furo no
    meio, luz no alto à esquerda. A versão do mouse em cima é mais clara e tem
    contorno de latão claro, como os carimbos erguidos."""
    import math
    size, center = 18, 8.5
    for name, body, light, dark, rim in (("gear", "brass1", "brass2", "brass0", "void"), ("gear_hover", "brass2", "brass3", "brass1", "brass3")):
        img = new(size, size)
        px = img.load()
        for y in range(size):
            for x in range(size):
                dx, dy = x - center, y - center
                r = math.hypot(dx, dy)
                angle = math.atan2(dy, dx) % (2 * math.pi)
                tooth = (angle / (2 * math.pi) * 8 + 0.25) % 1.0 < 0.5
                outer = 7.6 if tooth else 5.8
                if 2.3 < r <= outer:
                    color = body
                    if r > outer - 1.2 and dx + dy < -1:
                        color = light
                    elif r > outer - 1.2 and dx + dy > 2:
                        color = dark
                    elif r < 3.4:
                        color = dark
                    px[x, y] = rgba(color)
        outline(img, rim)
        save(img, name + ".png")


def bell_glow():
    """Halo quente do sino (56x44): elipse em três anéis de alfa, com
    pontilhado ordenado entre eles para a borda não virar degrau. O balcão
    varia a transparência do sprite inteiro (pulso e hover)."""
    import math
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    w, h = 56, 44
    img = new(w, h)
    px = img.load()
    rings = [(0.45, 150, "lamp2"), (0.75, 95, "lamp"), (1.0, 45, "lamp")]
    for y in range(h):
        for x in range(w):
            d = math.hypot((x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2))
            if d >= 1.0:
                continue
            t = bayer[y % 4][x % 4] / 16 * 0.18
            for edge, alpha, color in rings:
                if d + t < edge:
                    px[x, y] = rgba(color, alpha)
                    break
    save(img, "bell_glow.png")


if __name__ == "__main__":
    glyphs = all_glyphs()
    write_font(glyphs, 1, "pixel_font", "Atelier Pixel")
    write_font(glyphs, 2, "pixel_font_big", "Atelier Pixel Big")
    write_font(title_glyphs(glyphs), 1, "pixel_font_title", "Atelier Pixel Title", cell=13, line=14, base=11)
    tiny = tiny_glyphs()
    write_font(tiny, 1, "pixel_font_tiny", "Atelier Pixel Tiny", cell=8, line=9, base=7)
    silhouette()
    bubble_9(); stamp_box(); bubble_tail(); gear(); bell_glow()
    print("pixel art written to", OUT, "-", len(glyphs), "glyphs,", len(tiny), "tiny glyphs")
