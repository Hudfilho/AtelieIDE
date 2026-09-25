"""Funções comuns da conversão da arte do balcão (ver import_desk_art.py).

Cada estilo do balcão tem os assets em art/concepts/desk/<estilo>/ e gera os
sprites em art/desk/<estilo>/. Os tamanhos abaixo valem para todos os estilos:
o layout do balcão (Desk.tscn) e o orçamento de texto não mudam com o estilo.
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Tamanhos finais (px do balcão), iguais em todos os estilos; têm de bater com
# Desk.tscn e com o tema (as texturas dos papéis são trocadas, as margens não).
STAMP_HEIGHT = 58
TRAY_SIZE = (139, 60)
BELL_SIZE = 30
CANDLE_HEIGHT = 36
DAY_CARD_SIZE = (88, 123)
REQUEST_SIZE = (244, 212)
NOTE_SIZE = (188, 122)
BOOK_SIZE = (202, 212)
BACKDROP_SIZE = (640, 360)


class StyleFiles:
    """Onde ler os assets e gravar os sprites de um estilo."""

    def __init__(self, style):
        self.style = style
        self.src = os.path.join(ROOT, "art", "concepts", "desk", style)
        self.out = os.path.join(ROOT, "art", "desk", style)
        os.makedirs(self.out, exist_ok=True)

    def _path(self, name):
        for ext in (".webp", ".png"):
            path = os.path.join(self.src, name + ext)
            if os.path.exists(path):
                return path
        raise FileNotFoundError(os.path.join(self.src, name))

    def load(self, name):
        return np.array(Image.open(self._path(name)).convert("RGB"))

    def load_rgba(self, name):
        return np.array(Image.open(self._path(name)).convert("RGBA"))

    def save(self, img, name):
        img.save(os.path.join(self.out, name + ".png"))


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


def object_sprites(files, head, name, flies=True):
    """Objeto clicável em pé (AtelierDeskStamp): o sprite em repouso com 4 px
    de folga em cima, o erguido (2 px acima, contorno de latão) e a "cabeça"
    solta, que é a que voa até o papel (só para os carimbos)."""
    if flies:
        files.save(head, name + "_head")
    w, h = head.size
    rest = Image.new("RGBA", (w + 2, h + 4), (0, 0, 0, 0))
    rest.alpha_composite(head, (1, 4))
    files.save(rest, name)
    raised = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    raised.alpha_composite(head, (1, 1))
    lift = Image.new("RGBA", (w + 2, h + 4), (0, 0, 0, 0))
    lift.alpha_composite(outline_color(raised, (245, 220, 138, 255)), (0, 1))
    files.save(lift, name + "_lift")


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
