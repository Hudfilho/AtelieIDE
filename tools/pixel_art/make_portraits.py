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
}


def cutout(rgb, tolerance=40, erode=2):
    img = cv2.GaussianBlur(np.array(rgb), (3, 3), 0).astype(float)
    h, w = img.shape[:2]
    border = np.concatenate([img[0, :], img[:, 0], img[:, -1]])
    bright = border[border.mean(axis=1) > 180]
    ref = np.median(bright if len(bright) else border, axis=0)
    candidate = (np.linalg.norm(img - ref, axis=2) < tolerance).astype(np.uint8)
    _, labels = cv2.connectedComponents(candidate, connectivity=4)
    touching = set(labels[0, :]) | set(labels[:, 0]) | set(labels[:, -1])
    touching.discard(0)
    background = np.isin(labels, list(touching)) & (candidate == 1)
    fg = (~background).astype(np.uint8)
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


def shrink(rgb, alpha):
    rgba = rgb.convert("RGBA")
    rgba.putalpha(Image.fromarray(alpha))
    small = np.array(rgba.convert("RGBa").resize((SIZE, SIZE), Image.BOX).convert("RGBA"))
    small[..., 3] = np.where(small[..., 3] >= 110, 255, 0)
    return Image.fromarray(small)


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


def make(character, sheet_name, boxes):
    sheet = Image.open(os.path.join(SOURCES, sheet_name)).convert("RGB")
    smalls = {}
    for mood, (x, y, side) in boxes.items():
        crop = sheet.crop((x, y, x + side, y + side))
        alpha = cutout(crop)
        crop = crop.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
        crop = ImageEnhance.Contrast(crop).enhance(1.08)
        smalls[mood] = shrink(crop, alpha)
    joined = Image.new("RGB", (SIZE * len(smalls), SIZE))
    for i, img in enumerate(smalls.values()):
        joined.paste(img.convert("RGB"), (i * SIZE, 0), img)
    palette = joined.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT)
    os.makedirs(os.path.join(OUT, character), exist_ok=True)
    for mood, img in smalls.items():
        flat = img.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        flat.putalpha(img.getchannel("A"))
        outline(flat).save(os.path.join(OUT, character, mood + ".png"))
    return list(smalls)


if __name__ == "__main__":
    for character, (sheet_name, boxes) in CHARACTERS.items():
        moods = make(character, sheet_name, boxes)
        print(character, ", ".join(moods))
