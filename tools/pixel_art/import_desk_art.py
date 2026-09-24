"""Arte de produção do balcão a partir dos assets em art/concepts/desk/.

Os assets foram pintados em alta resolução; aqui eles viram sprites na grade de
640x360 do balcão (escala inteira, ver AtelierPixelFrame):

- o fundo (backdrop.webp) já tem quase exatamente 640x360 "pixels de arte":
  basta reduzir por área. Os objetos que o fundo traz pintados e que o jogo
  desenha por cima (os pegadores da bandeja de carimbos, a beirada do
  pergaminho) são cobertos com textura do próprio fundo;
- objetos soltos (carimbos, bandeja, sino, vela, cartão do dia) são recortados
  do fundo liso e reduzidos;
- papéis com texto (pedido, nota, livro de regras) são remontados em fatias:
  cantos e bordas do asset em escala uniforme, miolo limpo (linhas pautadas
  apagadas) esticado até o tamanho que o texto do jogo precisa. Os tamanhos
  vêm do orçamento de texto (AtelierContentBudget) e do layout de Desk.tscn.

Requer: pillow, numpy, opencv-python.
Rodar: python tools/pixel_art/import_desk_art.py
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "concepts", "desk")
OUT = os.path.join(ROOT, "art", "pixel")

# Tamanhos finais (px do balcão); têm de bater com Desk.tscn e com o tema.
STAMP_HEIGHT = 58
TRAY_SIZE = (139, 60)
BELL_SIZE = 30
CANDLE_HEIGHT = 36
DAY_CARD_WIDTH = 88


def load(name):
    return np.array(Image.open(os.path.join(SRC, name + ".webp")).convert("RGB"))


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))


def largest(mask):
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    if count <= 1:
        return mask.astype(np.uint8)
    return (labels == 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))).astype(np.uint8)


def flat_cutout(rgb, tolerance=26):
    """Objeto sobre fundo liso: fundo é o que tem a cor das bordas, ligado a
    elas, mais bolsões dessa cor fechados dentro do objeto (a alça da vela)."""
    img = cv2.GaussianBlur(rgb, (5, 5), 0).astype(float)
    border = np.concatenate([img[0], img[-1], img[:, 0], img[:, -1]])
    ref = np.median(border, axis=0)
    close = (np.linalg.norm(img - ref, axis=2) < tolerance).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(close, connectivity=4)
    background = np.zeros(close.shape, bool)
    edge = set(labels[0]) | set(labels[-1]) | set(labels[:, 0]) | set(labels[:, -1])
    for i in range(1, count):
        if i in edge or stats[i, cv2.CC_STAT_AREA] > 400:
            background |= labels == i
    return largest(~background)


def grabcut(rgb, rect, iterations=6):
    img = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    mask = np.zeros(img.shape[:2], np.uint8)
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(img, mask, rect, bgd, fgd, iterations, cv2.GC_INIT_WITH_RECT)
    fg = ((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)).astype(np.uint8)
    return largest(cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)))


def crop_to(rgb, mask):
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1]


def shrink(rgb, mask, size):
    """Redução por área com alfa pré-multiplicado; o alfa final é binário."""
    img = Image.fromarray(rgb).convert("RGBA")
    img.putalpha(Image.fromarray((mask > 0).astype(np.uint8) * 255))
    out = np.array(img.convert("RGBa").resize(size, Image.BOX).convert("RGBA"))
    out[..., 3] = np.where(out[..., 3] >= 128, 255, 0)
    return Image.fromarray(out)


def quantize(img, colors):
    alpha = img.getchannel("A")
    flat = img.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = flat.convert("RGBA")
    out.putalpha(alpha)
    return out


def fit_height(rgb, mask, height):
    crop, m = crop_to(rgb, mask)
    width = max(1, round(crop.shape[1] * height / crop.shape[0]))
    return shrink(crop, m, (width, height))


def fit_width(rgb, mask, width):
    crop, m = crop_to(rgb, mask)
    height = max(1, round(crop.shape[0] * width / crop.shape[1]))
    return shrink(crop, m, (width, height))


# ======================================================================
# Fundo
# ======================================================================
def backdrop():
    src = load("backdrop")
    img = np.array(Image.fromarray(src).resize((640, 360), Image.BOX)).copy()
    # Pegadores dos carimbos pintados atrás da bandeja: os carimbos do jogo
    # ficam na frente, então a gaveta do armário e os livros voltam a aparecer
    # (copiados das linhas logo acima).
    img[146:172, 470:560] = img[120:146, 470:560]
    img[146:172, 560:606] = img[120:146, 560:606]
    # Beirada do pergaminho pintado que sobraria entre o pedido e a nota.
    band = img[174:203, 436:472].copy()
    for y in range(203, 298, band.shape[0]):
        rows = min(band.shape[0], 298 - y)
        img[y:y + rows, 436:472] = band[:rows]
    out = Image.fromarray(img).convert("RGBA")
    save(quantize(out, 200), "backdrop")


# ======================================================================
# Carimbos, bandeja, sino, vela, cartão do dia
# ======================================================================
def outline_color(img, color):
    """Contorno de 1 px em volta do que é opaco (para o carimbo erguido)."""
    a = np.array(img)
    solid = a[..., 3] > 0
    grown = solid.copy()
    grown[1:, :] |= solid[:-1, :]
    grown[:-1, :] |= solid[1:, :]
    grown[:, 1:] |= solid[:, :-1]
    grown[:, :-1] |= solid[:, 1:]
    a[grown & ~solid] = color
    return Image.fromarray(a)


def object_sprites(head, name, flies=True):
    """Objeto clicável em pé (AtelierDeskStamp): o sprite em repouso com 4 px
    de folga em cima, o erguido (2 px acima, contorno de latão) e a "cabeça"
    solta, que é a que voa até o papel (só para os carimbos)."""
    if flies:
        save(head, name + "_head")
    w, h = head.size
    rest = Image.new("RGBA", (w + 2, h + 4), (0, 0, 0, 0))
    rest.alpha_composite(head, (1, 4))
    save(rest, name)
    raised = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    raised.alpha_composite(head, (1, 1))
    lift = Image.new("RGBA", (w + 2, h + 4), (0, 0, 0, 0))
    lift.alpha_composite(outline_color(raised, (245, 220, 138, 255)), (0, 1))
    save(lift, name + "_lift")


def stamps():
    src = load("stamps")
    for name, rect in (("stamp_approve", (250, 100, 290, 565)), ("stamp_reject", (720, 100, 290, 565))):
        object_sprites(quantize(fit_height(src, grabcut(src, rect), STAMP_HEIGHT), 48), name)
    # Frente da bandeja (poços de tinta e borda), no lugar da bandeja pintada no fundo.
    tray = src[655:1110, 40:1175]
    mask = flat_cutout(src)[655:1110, 40:1175]
    save(quantize(shrink(tray, mask, TRAY_SIZE), 48), "stamp_tray")


def bell():
    src = load("bell")
    object_sprites(quantize(fit_height(src, flat_cutout(src), BELL_SIZE), 32), "bell", flies=False)


def candle():
    src = load("candle")
    save(quantize(fit_height(src, flat_cutout(src), CANDLE_HEIGHT), 32), "candle")


def day_card():
    src = load("day_card")
    save(quantize(fit_width(src, flat_cutout(src), DAY_CARD_WIDTH), 48), "day_card")


# ======================================================================
# Papéis remontados em fatias
# ======================================================================
def erase_ink(rgb, region, keep=None, threshold=18, grow=3):
    """Apaga traços escuros (linhas pautadas, caixas) dentro de region
    (máscara), preenchendo com o pergaminho em volta. keep protege partes."""
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.int16)
    paper = cv2.medianBlur(gray.astype(np.uint8), 41).astype(np.int16)
    ink = ((paper - gray) > threshold) & region
    if keep is not None:
        ink &= ~keep
    ink = cv2.dilate(ink.astype(np.uint8), np.ones((2 * grow + 1, 2 * grow + 1), np.uint8))
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    return cv2.cvtColor(cv2.inpaint(bgr, ink, 7, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)


def rect_mask(shape, rects):
    mask = np.zeros(shape[:2], bool)
    for x0, y0, x1, y1 in rects:
        mask[y0:y1, x0:x1] = True
    return mask


def stretch(block, width, height):
    return cv2.resize(block, (width, height), interpolation=cv2.INTER_LINEAR)


def compose(rgba, xs, ys, size, side_rows=None, cap_cols=None, center=None, outer=0):
    """Remonta um papel em fatias, na resolução da fonte.

    xs = (x0, xa, xb, x1) e ys = (y0, ya, yb, y1) cortam cantos, bordas e
    miolo. Cantos são copiados em escala uniforme; bordas e miolo são
    esticados (nada se repete, então não aparecem emendas). side_rows e
    cap_cols escolhem trechos lisos das laterais e de cima/baixo, e center o
    trecho do miolo, para enfeites não saírem esticados. Os primeiros outer px
    de cada lado (a beirada rasgada e a linha da moldura) vêm do lado inteiro,
    para a beirada continuar irregular."""
    x0, xa, xb, x1 = xs
    y0, ya, yb, y1 = ys
    width, height = size
    left, right = xa - x0, x1 - xb
    top, bottom = ya - y0, y1 - yb
    sr0, sr1 = side_rows or (ya, yb)
    cc0, cc1 = cap_cols or (xa, xb)
    cx0, cy0, cx1, cy1 = center or (xa, ya, xb, yb)
    out = np.zeros((height, width, 4), np.uint8)
    inner_w, inner_h = width - left - right, height - top - bottom
    out[top:height - bottom, left:width - right] = stretch(rgba[cy0:cy1, cx0:cx1], inner_w, inner_h)
    out[:top, left:width - right] = stretch(rgba[y0:ya, cc0:cc1], inner_w, top)
    out[height - bottom:, left:width - right] = stretch(rgba[yb:y1, cc0:cc1], inner_w, bottom)
    out[top:height - bottom, :left] = stretch(rgba[sr0:sr1, x0:xa], left, inner_h)
    out[top:height - bottom, width - right:] = stretch(rgba[sr0:sr1, xb:x1], right, inner_h)
    if outer:
        out[:outer, left:width - right] = stretch(rgba[y0:y0 + outer, xa:xb], inner_w, outer)
        out[height - outer:, left:width - right] = stretch(rgba[y1 - outer:y1, xa:xb], inner_w, outer)
        out[top:height - bottom, :outer] = stretch(rgba[ya:yb, x0:x0 + outer], outer, inner_h)
        out[top:height - bottom, width - outer:] = stretch(rgba[ya:yb, x1 - outer:x1], outer, inner_h)
    out[:top, :left] = rgba[y0:ya, x0:xa]
    out[:top, width - right:] = rgba[y0:ya, xb:x1]
    out[height - bottom:, :left] = rgba[yb:y1, x0:xa]
    out[height - bottom:, width - right:] = rgba[yb:y1, xb:x1]
    return out


def paste(dst, src, x, y):
    """Cola src (RGBA) sobre dst respeitando o alfa de src (cortando nas bordas)."""
    h = min(src.shape[0], dst.shape[0] - y)
    w = min(src.shape[1], dst.shape[1] - x)
    src = src[:h, :w]
    region = dst[y:y + h, x:x + w]
    a = src[..., 3:4].astype(float) / 255.0
    region[..., :3] = (src[..., :3] * a + region[..., :3] * (1 - a)).astype(np.uint8)
    region[..., 3] = np.maximum(region[..., 3], src[..., 3])


def with_alpha(rgb, mask):
    return np.dstack([rgb, (mask > 0).astype(np.uint8) * 255])


def finish(canvas, size, colors=64):
    """Reduz a composição (na escala da fonte) para o tamanho final."""
    rgb, alpha = canvas[..., :3], canvas[..., 3]
    return quantize(shrink(np.ascontiguousarray(rgb), alpha, size), colors)


REQUEST_SIZE = (244, 212)
REQUEST_SCALE = 0.16


def request():
    src = load("request")
    mask = flat_cutout(src)
    # Miolo: some a caixa do título, as linhas pautadas e o selo de baixo;
    # ficam a moldura, os enfeites dos cantos e as estrelas das laterais.
    corners = rect_mask(src.shape, [(120, 1110, 290, 1260), (830, 1110, 1000, 1260)])
    clean = erase_ink(src, rect_mask(src.shape, [(192, 296, 932, 1200)]), keep=corners)
    # O brasão (lua) sai do topo e volta depois, menor, centrado.
    emblem_box = (262, 96, 868, 300)
    emblem = src[emblem_box[1]:emblem_box[3], emblem_box[0]:emblem_box[2]]
    emblem_ink = erase_ink(src, rect_mask(src.shape, [emblem_box]), threshold=14)
    top_clean = clean.copy()
    top_clean[150:300, 262:868] = emblem_ink[150:300, 262:868]
    rgba = with_alpha(top_clean, mask)
    target = (round(REQUEST_SIZE[0] / REQUEST_SCALE), round(REQUEST_SIZE[1] / REQUEST_SCALE))
    canvas = compose(rgba, (70, 290, 830, 1040), (60, 300, 1100, 1330), target,
                     side_rows=(420, 520), cap_cols=(300, 420), center=(300, 440, 820, 980), outer=80)
    # Brasão por cima da moldura de cima, em metade do tamanho (lua e ramos).
    gray = cv2.cvtColor(emblem, cv2.COLOR_RGB2GRAY).astype(np.int16)
    ink = (cv2.medianBlur(gray.astype(np.uint8), 41).astype(np.int16) - gray) > 12
    ink = cv2.dilate(ink.astype(np.uint8), np.ones((5, 5), np.uint8))
    small = cv2.resize(np.dstack([emblem, ink * 255]), None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA)
    paste(canvas, small, (target[0] - small.shape[1]) // 2, 20)
    save(finish(canvas, REQUEST_SIZE), "parchment")


NOTE_SIZE = (188, 122)


def pushpin():
    """Tacha de latão 9x9 (cabeça redonda com brilho e sombra de 1 px)."""
    rows = ["..ooooo..", ".oBBBBBo.", "oBWHBBBBo", "oBHBBBbBo", "oBBBBBbBo", "oBBBBbbBo", ".obbbbbo.", "..ooooo..", "....s...."]
    colors = {"o": (74, 44, 24, 255), "B": (214, 168, 72, 255), "b": (160, 112, 40, 255), "H": (245, 220, 138, 255),
              "W": (255, 244, 200, 255), "s": (60, 36, 20, 160)}
    img = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in colors:
                img.putpixel((x, y), colors[c])
    return img


def note():
    """Bilhete preso com alfinete. O asset vem levemente girado e com sombra:
    o papel é endireitado (só o papel claro, sem a sombra) e esticado até o
    tamanho da nota. O alfinete do asset, nesse tamanho, vira borrão: é
    redesenhado com as cores de latão dos assets."""
    src = load("note")
    pin_box = (470, 280, 620, 420)
    clean = erase_ink(src, rect_mask(src.shape, [(280, 500, 850, 900)]), threshold=22)
    shadow_box = (pin_box[0] - 30, pin_box[1] - 30, pin_box[2] + 30, pin_box[3] + 30)
    clean = erase_ink(clean, rect_mask(src.shape, [shadow_box]), threshold=-255, grow=2)
    gray = cv2.cvtColor(src, cv2.COLOR_RGB2GRAY)
    bright = (gray > 120).astype(np.uint8)
    # O alfinete e a sombra dele abrem um dente na beirada de cima: fecha.
    bright[pin_box[1] + 70:shadow_box[3], shadow_box[0]:shadow_box[2]] = 1
    paper = largest(cv2.morphologyEx(bright, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8)))
    # Buracos escuros dentro do papel (marcadores, sombra do alfinete) são papel.
    outside = np.zeros((paper.shape[0] + 2, paper.shape[1] + 2), np.uint8)
    cv2.floodFill((1 - paper).astype(np.uint8).copy(), outside, (0, 0), 1, flags=4 | cv2.FLOODFILL_MASK_ONLY | (1 << 8))
    paper = (outside[1:-1, 1:-1] == 0).astype(np.uint8)
    (cx, cy), _, angle = cv2.minAreaRect(np.column_stack(np.nonzero(paper)[::-1]).astype(np.float32))
    if angle > 45:
        angle -= 90
    turn = cv2.getRotationMatrix2D((cx, cy), angle, 1.0)
    h, w = paper.shape
    clean = cv2.warpAffine(clean, turn, (w, h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    paper = cv2.warpAffine(paper, turn, (w, h), flags=cv2.INTER_NEAREST)
    body_rgb, body_mask = crop_to(clean, paper)
    # O papel começa 3 px abaixo do topo: o alfinete (pequeno) fica na
    # beirada, acima da primeira linha de texto (margem de cima do tema: 16).
    body = shrink(body_rgb, body_mask, (NOTE_SIZE[0], NOTE_SIZE[1] - 3))
    out = Image.new("RGBA", NOTE_SIZE, (0, 0, 0, 0))
    out.alpha_composite(body, (0, 3))
    out.alpha_composite(pushpin(), ((NOTE_SIZE[0] - 9) // 2, 0))
    save(quantize(out, 48), "note")


BOOK_SIZE = (202, 212)
BOOK_SCALE = 0.12
# Largura da pilha de folhas que sai de cada lado (colunas da fonte).
BOOK_STACK_CUT = 80
# Molduras das páginas (px do livro final): colunas de cada página e linhas.
BOOK_PAGE_FRAMES = ((10, 95), (106, 191))
BOOK_FRAME_Y = (9, 186)
BOOK_INK = (138, 92, 50, 255)


def book():
    src = load("rulebook")
    mask = flat_cutout(src)
    # Páginas sem as linhas pautadas; a moldura e as estrelas dos cantos ficam.
    pages = rect_mask(src.shape, [(205, 275, 575, 770), (680, 275, 1050, 770)])
    clean = erase_ink(src, pages, threshold=14)
    rgba = with_alpha(clean, mask)
    # A pilha de folhas nas laterais afina (menos colunas) para sobrar texto.
    rgba = np.concatenate([rgba[:, :70], rgba[:, 70 + BOOK_STACK_CUT:1110], rgba[:, 1110 + BOOK_STACK_CUT:]], axis=1)
    seam = 630 - BOOK_STACK_CUT
    half_w = round(BOOK_SIZE[0] / 2 / BOOK_SCALE)
    body_h = round((BOOK_SIZE[1] - 12) / BOOK_SCALE)
    body = (160, 310, 820, 960)
    left = compose(rgba, (20, 190, 470, seam), body, (half_w, body_h), side_rows=(330, 470), cap_cols=(260, 340), center=(230, 320, 520, 760))
    # A metade direita é o espelho da esquerda: a capa direita do asset tem
    # abas e fecho em toda a altura, sem trecho liso para esticar (e as abas
    # ficariam embaixo do pedido de qualquer jeito).
    right = np.ascontiguousarray(left[:, ::-1])
    canvas = np.zeros((round(BOOK_SIZE[1] / BOOK_SCALE), half_w * 2, 4), np.uint8)
    canvas[:body_h, :half_w] = left
    canvas[:body_h, half_w:] = right
    # Fechos de latão no meio das laterais e a fita marcadora saindo do vinco.
    for box, x in (((25, 480, 130, 620), 0), ((1140 - BOOK_STACK_CUT, 490, 1220 - BOOK_STACK_CUT, 610), None)):
        clasp = rgba[box[1]:box[3], box[0]:box[2]]
        cx = x if x is not None else half_w * 2 - clasp.shape[1]
        paste(canvas, clasp, cx, body_h // 2 - clasp.shape[0] // 2)
    ribbon = rgba[860:1115, 615:765]
    paste(canvas, ribbon, half_w - ribbon.shape[1] // 2, body_h - 110)
    # Cantoneiras de latão inteiras (o corte da pilha de folhas as partiria).
    full = with_alpha(src, mask)
    for box, at_right, at_bottom in (((28, 195, 150, 300), False, False), ((1105, 195, 1200, 300), True, False),
                                     ((20, 835, 140, 955), False, True), ((1130, 835, 1235, 955), True, True)):
        piece = full[box[1]:box[3], box[0]:box[2]]
        px = canvas.shape[1] - piece.shape[1] if at_right else 0
        py = body_h - piece.shape[0] if at_bottom else 0
        paste(canvas, piece, px, py)
    spread = finish(canvas, BOOK_SIZE)
    # As molduras finas das páginas somem na redução: são redesenhadas a 1 px,
    # com as estrelas dos cantos recortadas do próprio asset.
    star_box = (170, 222, 262, 300)
    star = src[star_box[1]:star_box[3], star_box[0]:star_box[2]]
    gray = cv2.cvtColor(star, cv2.COLOR_RGB2GRAY).astype(np.int16)
    star_ink = ((cv2.medianBlur(gray.astype(np.uint8), 31).astype(np.int16) - gray) > 16).astype(np.uint8)
    star_img = shrink(star, cv2.dilate(star_ink, np.ones((3, 3), np.uint8)), (9, 8))
    pixels = spread.load()
    for x0, x1 in BOOK_PAGE_FRAMES:
        y0, y1 = BOOK_FRAME_Y
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                if pixels[x, y][3]:
                    pixels[x, y] = BOOK_INK
        for y in range(y0, y1 + 1):
            for x in (x0, x1):
                if pixels[x, y][3]:
                    pixels[x, y] = BOOK_INK
        for sx, sy, flip_x, flip_y in ((x0, y0, False, False), (x1 - 8, y0, True, False), (x0, y1 - 7, False, True), (x1 - 8, y1 - 7, True, True)):
            piece = star_img
            if flip_x:
                piece = piece.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if flip_y:
                piece = piece.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            spread.alpha_composite(piece, (sx, sy))
    save(spread, "book_spread")


if __name__ == "__main__":
    backdrop()
    stamps()
    bell()
    candle()
    day_card()
    request()
    note()
    book()
    print("desk art written to", OUT)
