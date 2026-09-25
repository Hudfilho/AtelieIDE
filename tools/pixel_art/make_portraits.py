"""Retratos dos clientes para a janela do balcão (92x92, pixel art).

Converte os painéis de expressão das fichas de personagem
(art/concepts/portraits/*.webp) em PNGs de pixel art, um por humor:

1. recorta um quadrado do painel;
2. separa o personagem do fundo de pergaminho: o fundo é o que tem a cor do
   pergaminho e encosta nas bordas de cima e dos lados. O contorno escuro do
   desenho protege partes claras do personagem, como um capuz creme. Sobra só
   o maior pedaço (enfeites soltos, como "!", engrenagens e balões, saem) e a
   franja clara da borda é comida;
3. reduz para 92x92 por média de área, com alfa binário;
4. usa uma paleta comum às expressões do personagem (32 cores, sem pontilhado),
   para as cores não pularem de uma expressão para outra;
5. contorna a silhueta com 1 px escuro, menos embaixo, onde o busto encosta no
   balcão.

As fichas do estilo novo (CUTOUTS) mudam os passos 2 e 4. O recorte depende do
fundo do painel:
- cutout_painted: pergaminho com enfeites pintados (nuvens, pagodes, folhagem)
  que não têm a cor dele e encostam no personagem. É um GrabCut: fundo certo é
  o pergaminho ligado à borda de cima, personagem certo é o miolo da massa do
  corpo (o que sobra de uma abertura grande, que some com as pinceladas finas);
- cutout_inked: traço de nanquim com o corpo da cor do pergaminho. O fundo é o
  que se alcança da borda de cima sem cruzar contorno escuro, mais os bolsões
  lisos de pergaminho nos lados (o corpo tem textura, o papel não);
- cutout_sky: painel pintado até a borda, sem pergaminho. O fundo é só o céu
  dos cantos de cima, alcançado por cores parecidas com as de cada canto.
A paleta é um k-means em Lab só dos pixels opacos, que guarda acentos pequenos
como o azul das tatuagens; o median cut os misturava com a pele.

As fichas são o material de referência; o que o jogo usa são os PNGs gerados
em art/portraits/<personagem>/<humor>.png e os recursos AtelierPortrait em
data/portraits/. Fatos de jogo (raça, idade, nome) continuam vindo das
encomendas, não das fichas.

Requer: pillow, numpy, opencv-python.
Rodar: python tools/pixel_art/make_portraits.py
"""
import os

import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES = os.path.join(ROOT, "art", "concepts", "portraits")
OUT = os.path.join(ROOT, "art", "portraits")

SIZE = 92
COLORS = 32
OUTLINE = (26, 16, 22, 255)

# Personagem -> ficha e, por humor, o quadrado (x, y, lado) do painel na ficha.
CHARACTERS = {
    "anderdingus": ("anderdingus.webp", {
        "neutral": (546, 168, 238),   # Neutral
        "happy": (546, 523, 238),     # Excited: "HEHEHE! Big fire, big fire!"
        "upset": (813, 523, 238),     # Grumpy (também serve de "uneasy")
    }),
    "mira_holloway": ("mira_holloway.webp", {
        "neutral": (541, 170, 238),
        "happy": (806, 170, 238),
        "uneasy": (541, 545, 238),    # preocupada
        "upset": (806, 545, 238),     # desconfiada
    }),
    "elenia_valehart": ("elenia_valehart.webp", {
        "neutral": (24, 634, 242),
        "happy": (291, 634, 242),
        "uneasy": (559, 634, 242),    # Thoughtful
        "upset": (824, 634, 242),     # Skeptical
    }),
    "sleego": ("sleego.webp", {
        "neutral": (534, 172, 238),
        "happy": (799, 172, 238),
        "uneasy": (534, 552, 238),    # Thoughtful
        "upset": (799, 552, 238),     # Concerned
    }),
    "kothar": ("kothar.webp", {
        "neutral": (528, 214, 262),
        "happy": (792, 214, 262),     # rindo
        "uneasy": (795, 578, 262),    # mão no queixo
        "upset": (528, 578, 262),     # olhar desconfiado
    }),
    # chrono_genesis_lore.webp é a ficha com história e paleta; não é recortada.
    "chrono_genesis": ("chrono_genesis.webp", {
        "neutral": (568, 214, 248),   # Calm
        "happy": (840, 234, 248),
        "uneasy": (569, 548, 248),    # Thoughtful
        "upset": (850, 548, 248),     # Concerned
    }),
    # As fichas <personagem>_lore.webp trazem história e paleta; não são recortadas.
    "yuval": ("yuval.webp", {
        "neutral": (566, 530, 244),   # Watchful: chega desconfiado de uma loja de magia
        "happy": (566, 192, 244),     # Calm
        "uneasy": (842, 530, 244),    # Concerned
        "upset": (842, 192, 244),     # Stern
    }),
    "nemo": ("nemo.webp", {
        "neutral": (618, 94, 212),    # Calm
        "happy": (860, 94, 212),      # Joyful
        "uneasy": (622, 436, 208),    # Battle Focus (sem o tentáculo da figura grande)
        "upset": (860, 436, 212),     # Fury State
    }),
    "rango": ("rango.webp", {
        "neutral": (566, 196, 244),   # Calm
        "happy": (842, 188, 244),
        "uneasy": (566, 530, 244),    # Curious
        "upset": (842, 530, 244),     # Concerned
    }),
    # Ficha única, com oito expressões em painéis menores.
    "reed": ("reed.webp", {
        "neutral": (451, 338, 145),   # Neutro
        "happy": (605, 342, 145),     # Sorridente
        "uneasy": (605, 566, 145),    # Pensativo
        "upset": (452, 566, 145),     # Bravo
    }),
}
# Fichas do estilo novo: recorte de cada uma (veja o topo do arquivo). A paleta
# delas é por k-means em Lab.
CUTOUTS = {
    "chrono_genesis": lambda rgb: cutout_painted(rgb),
    # Folhagem bege atrás do cabelo: tolerância maior para contar como papel.
    "yuval": lambda rgb: cutout_painted(rgb, tolerance=80),
    "nemo": lambda rgb: cutout_sky(rgb),
    "rango": lambda rgb: cutout_inked(rgb),
    "reed": lambda rgb: cutout_painted(rgb),
}
# Quem enche o painel inteiro (o sino do Nemo vai de lado a lado) sai menor na
# tela de 92x92, apoiado embaixo, para sobrar janela em volta.
FIT = {"nemo": 84}
# cutout_painted (px da ficha): abertura que some com as nuvens, erosão até o
# miolo certo do corpo e folga em volta dele.
BODY_OPEN = 21
BODY_CORE = 17
BODY_MARGIN = 9
# cutout_inked: luminância do contorno, quanto ele engrossa para fechar falhas e
# textura (desvio padrão local) abaixo da qual um bolsão é papel liso.
INK_DARK = 120
INK_GROW = 5
INK_SMOOTH = 28
# cutout_sky: distância em Lab até a cor do canto, lado do quadrado amostrado
# nos cantos e abertura que solta as bolhas grudadas no personagem.
SKY_TOLERANCE = 30
SKY_PATCH = 12
SKY_OPEN = 11


def cutout(rgb, tolerance=40, erode=2):
    img = cv2.GaussianBlur(np.array(rgb), (3, 3), 0).astype(float)
    border = np.concatenate([img[0, :], img[:, 0], img[:, -1]])
    bright = border[border.mean(axis=1) > 180]
    ref = np.median(bright if len(bright) else border, axis=0)
    candidate = (np.linalg.norm(img - ref, axis=2) < tolerance).astype(np.uint8)
    _, labels = cv2.connectedComponents(candidate, connectivity=4)
    touching = set(labels[0, :]) | set(labels[:, 0]) | set(labels[:, -1])
    touching.discard(0)
    background = np.isin(labels, list(touching)) & (candidate == 1)
    return tidy((~background).astype(np.uint8), erode)


def _disk(size):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (size, size))


def cutout_painted(rgb, tolerance=40, erode=2):
    img = np.array(rgb)
    blur = cv2.GaussianBlur(img, (3, 3), 0).astype(float)
    top = blur[0, :]
    bright = top[top.mean(axis=1) > 180]
    ref = np.median(bright if len(bright) else top, axis=0)
    parchment = (np.linalg.norm(blur - ref, axis=2) < tolerance).astype(np.uint8)
    # Fundo certo só a partir de cima: nos lados, o creme pode ser a roupa.
    _, labels = cv2.connectedComponents(parchment, connectivity=4)
    sure_bg = np.isin(labels, list(set(labels[0, :]) - {0})) & (parchment == 1)
    # Massa do corpo: a maior, mais as que encostam embaixo (um ombro que uma
    # faixa de roupa creme separa do resto também é busto).
    opened = cv2.morphologyEx(1 - parchment, cv2.MORPH_OPEN, _disk(BODY_OPEN))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(opened, 8)
    keep = set(labels[-1, :]) - {0}
    if count > 1:
        keep.add(1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA])))
    body = np.isin(labels, list(keep)).astype(np.uint8)
    far = (parchment == 0) & (cv2.dilate(body, _disk(BODY_MARGIN)) == 0)
    mask = np.full(parchment.shape, cv2.GC_PR_FGD, np.uint8)
    mask[(parchment == 1) | far] = cv2.GC_PR_BGD
    mask[sure_bg] = cv2.GC_BGD
    mask[cv2.erode(body, _disk(BODY_CORE)) == 1] = cv2.GC_FGD
    # O GrabCut começa com um k-means: semente fixa, mesmo PNG a cada execução.
    cv2.setRNGSeed(0)
    models = (np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64))
    cv2.grabCut(img[..., ::-1].copy(), mask, None, *models, 5, cv2.GC_INIT_WITH_MASK)
    return tidy(np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8), erode)


def cutout_inked(rgb, tolerance=60, erode=2):
    img = np.array(rgb)
    blur = cv2.GaussianBlur(img, (3, 3), 0).astype(float)
    lum = blur @ [0.299, 0.587, 0.114]
    raw = img.astype(float) @ [0.299, 0.587, 0.114]
    texture = np.sqrt(np.maximum(cv2.blur(raw ** 2, (9, 9)) - cv2.blur(raw, (9, 9)) ** 2, 0))
    top = blur[0, :]
    ref = np.median(top[top.mean(axis=1) > 180], axis=0)
    grow = np.ones((INK_GROW, INK_GROW), np.uint8)
    barrier = cv2.dilate((lum < INK_DARK).astype(np.uint8), grow)
    _, labels = cv2.connectedComponents(1 - barrier, connectivity=4)
    from_top = set(labels[0, :]) - {0}
    background = np.isin(labels, list(from_top))
    # Nos lados, o creme pode ser o corpo cortado pelo quadrado: só vira fundo o
    # bolsão liso e da cor do pergaminho.
    for i in (set(labels[:, 0]) | set(labels[:, -1])) - from_top - {0}:
        region = labels == i
        if texture[region].mean() < INK_SMOOTH and np.linalg.norm(blur[region].mean(axis=0) - ref) < tolerance:
            background |= region
    # A barreira engrossada comeu a beirada do fundo: devolve o que encosta nele.
    background = cv2.dilate(background.astype(np.uint8), grow).astype(bool) & (lum >= INK_DARK)
    return tidy((~background).astype(np.uint8), erode)


def cutout_sky(rgb, erode=2):
    img = np.array(rgb)
    h, w = img.shape[:2]
    lab = cv2.cvtColor(cv2.GaussianBlur(img, (5, 5), 0), cv2.COLOR_RGB2LAB).astype(float)
    background = np.zeros((h, w), bool)
    for corner in (lab[2:2 + SKY_PATCH, 2:2 + SKY_PATCH], lab[2:2 + SKY_PATCH, -2 - SKY_PATCH:-2]):
        ref = np.median(corner.reshape(-1, 3), axis=0)
        near = (np.linalg.norm(lab - ref, axis=2) < SKY_TOLERANCE).astype(np.uint8)
        _, labels = cv2.connectedComponents(near, connectivity=4)
        # O céu vem de cima e desce pelos lados até a altura dos ombros.
        seeds = set(labels[0, :]) | set(labels[: h * 3 // 5, 0]) | set(labels[: h * 3 // 5, -1])
        background |= np.isin(labels, list(seeds - {0}))
    fg = cv2.morphologyEx((~background).astype(np.uint8), cv2.MORPH_OPEN, _disk(SKY_OPEN))
    return tidy(fg, erode)


def tidy(fg, erode):
    """Máscara 0/1 do personagem → alfa: sem ciscos, só o maior pedaço, sem
    buracos pequenos e sem a franja clara."""
    h, w = fg.shape
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(fg, 8)
    if count > 1:
        fg = (labels == 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))).astype(np.uint8)
    # Tapa buracos pequenos dentro do personagem.
    count, labels, stats, _ = cv2.connectedComponentsWithStats(1 - fg, 4)
    for i in range(1, count):
        x, y, bw, bh, area = stats[i]
        if x > 0 and y > 0 and x + bw < w and y + bh < h and area < w * h * 0.02:
            fg[labels == i] = 1
    # Come a franja clara, menos na base do busto (que encosta no balcão).
    base = fg[-erode:, :].copy()
    fg = cv2.erode(fg, np.ones((2 * erode + 1, 2 * erode + 1), np.uint8))
    fg[-erode:, :] = base & fg[-erode - 1, :]
    return fg * 255


def shrink(rgb, alpha, size=SIZE):
    """Reduz para size x size e apoia no pé da tela de SIZE x SIZE, centralizado."""
    rgba = rgb.convert("RGBA")
    rgba.putalpha(Image.fromarray(alpha))
    small = np.array(rgba.convert("RGBa").resize((size, size), Image.BOX).convert("RGBA"))
    small[..., 3] = np.where(small[..., 3] >= 110, 255, 0)
    canvas = np.zeros((SIZE, SIZE, 4), np.uint8)
    left = (SIZE - size) // 2
    canvas[SIZE - size:, left:left + size] = small
    return Image.fromarray(canvas)


def outline(img):
    a = np.array(img)
    solid = a[..., 3] > 0
    grown = solid.copy()
    grown[1:, :] |= solid[:-1, :]
    grown[:-1, :] |= solid[1:, :]
    grown[:, 1:] |= solid[:, :-1]
    grown[:, :-1] |= solid[:, 1:]
    ring = grown & ~solid
    ring[-1, :] = False
    a[ring] = OUTLINE
    return Image.fromarray(a)


def median_cut_palette(smalls):
    """Paleta comum às expressões (median cut); devolve quem achata cada uma."""
    joined = Image.new("RGB", (SIZE * len(smalls), SIZE))
    for i, img in enumerate(smalls):
        joined.paste(img.convert("RGB"), (i * SIZE, 0), img)
    palette = joined.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT)

    def flatten(img):
        flat = img.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        flat.putalpha(img.getchannel("A"))
        return flat
    return flatten


def lab_palette(smalls):
    """Paleta comum às expressões por k-means em Lab, só dos pixels opacos;
    devolve quem achata cada uma na cor mais próxima em Lab."""
    opaque = np.concatenate([a[a[..., 3] > 0][:, :3] for a in map(np.array, smalls)])
    lab = cv2.cvtColor(opaque.reshape(-1, 1, 3), cv2.COLOR_RGB2LAB).reshape(-1, 3).astype(np.float32)
    cv2.setRNGSeed(0)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.2)
    _, _, centers = cv2.kmeans(lab, COLORS, None, criteria, 4, cv2.KMEANS_PP_CENTERS)
    centers = np.clip(np.round(centers), 0, 255)
    colors = cv2.cvtColor(centers.astype(np.uint8).reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3)

    def flatten(img):
        a = np.array(img)
        pixels = cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2LAB).reshape(-1, 1, 3).astype(np.float32)
        nearest = np.argmin(((pixels - centers) ** 2).sum(axis=2), axis=1)
        a[..., :3] = colors[nearest].reshape(a.shape[:2] + (3,))
        return Image.fromarray(a)
    return flatten


def make(character, sheet_name, boxes):
    new_style = character in CUTOUTS
    sheet = Image.open(os.path.join(SOURCES, sheet_name)).convert("RGB")
    smalls = {}
    for mood, (x, y, side) in boxes.items():
        crop = sheet.crop((x, y, x + side, y + side))
        alpha = CUTOUTS[character](crop) if new_style else cutout(crop)
        crop = crop.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
        crop = ImageEnhance.Contrast(crop).enhance(1.08)
        smalls[mood] = shrink(crop, alpha, FIT.get(character, SIZE))
    flatten = (lab_palette if new_style else median_cut_palette)(list(smalls.values()))
    os.makedirs(os.path.join(OUT, character), exist_ok=True)
    for mood, img in smalls.items():
        outline(flatten(img)).save(os.path.join(OUT, character, mood + ".png"))
    return list(smalls)


if __name__ == "__main__":
    for character, (sheet_name, boxes) in CHARACTERS.items():
        moods = make(character, sheet_name, boxes)
        print(character, ", ".join(moods))
