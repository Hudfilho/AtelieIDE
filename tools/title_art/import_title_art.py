"""Arte da tela de título a partir de art/concepts/title/title.webp.

A ilustração tem o logotipo pintado (emblema e "Atelier"), a frase e três
botões pintados em inglês. O jogo é traduzido, então:

- o fundo (art/title/background.webp) fica com o logotipo e sem a frase e
  os botões: os traços claros da frase e os botões inteiros são apagados e
  preenchidos com a parede escura em volta. Os botões do jogo ficam
  exatamente onde estavam os pintados, então cobrem o preenchimento;
- as molduras dos botões (verde com ramos, escura com filete dourado) viram
  texturas de 9 fatias sem texto: as pontas com os enfeites ficam inteiras e
  o meio liso estica até a largura que o texto traduzido pedir. Há versões
  para o mouse em cima e para o clique. As texturas já saem na escala do
  palco do título (1280x720), a mesma do fundo na tela.

Requer: pillow, numpy, opencv-python.
Rodar: python tools/title_art/import_title_art.py
"""
import os

import cv2
import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "concepts", "title", "title.webp")
OUT = os.path.join(ROOT, "art", "title")

# Palco do título: a ilustração inteira ocupa 1280x720 (ver Title.tscn).
STAGE = (1280, 720)

TAGLINE = (552, 388, 1120, 424)
# Botões pintados (x0, y0, x1, y1) e onde cortar as pontas: (fim da ponta
# esquerda, início da ponta direita). O miolo entre elas é liso.
PRIMARY = (598, 461, 1075, 549)
PRIMARY_CAPS = (700, 955)
SECONDARY = (622, 552, 1050, 618)
SECONDARY_CAPS = (680, 1000)
BUTTONS = [PRIMARY, SECONDARY, (622, 620, 1050, 686)]
# Largura do miolo liso levada para a textura (px da ilustração).
MIDDLE = 24


def stage_scale(image):
    return STAGE[0] / image.shape[1]


def background(src):
    rgb = src.copy()
    mask = np.zeros(rgb.shape[:2], np.uint8)
    # Frase: só os traços claros (letras), com uma folga.
    x0, y0, x1, y1 = TAGLINE
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    letters = (gray[y0:y1, x0:x1] > 95).astype(np.uint8)
    mask[y0:y1, x0:x1] = cv2.dilate(letters, np.ones((7, 7), np.uint8))
    # Botões: a área inteira de cada um.
    for x0, y0, x1, y1 in BUTTONS:
        mask[y0 - 4:y1 + 4, x0 - 4:x1 + 4] = 1
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    out = cv2.cvtColor(cv2.inpaint(bgr, mask, 9, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(out).save(os.path.join(OUT, "background.webp"), quality=92, method=6)


def button_mask(piece):
    """Só o botão: moldura dourada, enfeites e o que está dentro da moldura.
    A parede em volta (e entre os cantos chanfrados) fica transparente."""
    r, g, b = [piece[..., i].astype(np.int16) for i in range(3)]
    gold = ((r - b) > 35) & ((r + g) > 200)
    # Fecha as falhas do filete (trechos mais apagados), senão o preenchimento
    # de fora vaza para dentro do botão.
    gold = cv2.morphologyEx(gold.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    gold = cv2.dilate(gold, np.ones((3, 3), np.uint8))
    outside = np.zeros((piece.shape[0] + 2, piece.shape[1] + 2), np.uint8)
    free = (1 - gold).astype(np.uint8)
    for x, y in ((0, 0), (piece.shape[1] - 1, 0), (0, piece.shape[0] - 1), (piece.shape[1] - 1, piece.shape[0] - 1)):
        if free[y, x] and not outside[y + 1, x + 1]:
            cv2.floodFill(free, outside, (x, y), 1, flags=4 | cv2.FLOODFILL_MASK_ONLY | (1 << 8))
    return (outside[1:-1, 1:-1] == 0).astype(np.uint8)


def button(src, box, caps, name):
    x0, y0, x1, y1 = box
    left_end, right_start = caps
    piece = src[y0:y1, x0:x1]
    mask = button_mask(piece)
    rgba = np.dstack([piece, mask * 255])
    a, b = left_end - x0, right_start - x0
    strip = np.concatenate([rgba[:, :a], rgba[:, a:a + MIDDLE], rgba[:, b:]], axis=1)
    scale = stage_scale(src)
    size = (round(strip.shape[1] * scale), round(strip.shape[0] * scale))
    img = Image.fromarray(np.ascontiguousarray(strip)).convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    img.save(os.path.join(OUT, name + ".png"))
    rgb, alpha = img.convert("RGB"), img.getchannel("A")
    for suffix, factor in (("_hover", 1.18), ("_pressed", 0.82)):
        state = ImageEnhance.Brightness(rgb).enhance(factor).convert("RGBA")
        state.putalpha(alpha)
        state.save(os.path.join(OUT, name + suffix + ".png"))
    # Margens de 9 fatias da textura, para o tema (px do palco).
    return round(a * scale), round((x1 - right_start) * scale), size


if __name__ == "__main__":
    src = np.array(Image.open(SRC).convert("RGB"))
    background(src)
    print("primary", button(src, PRIMARY, PRIMARY_CAPS, "button_primary"))
    print("secondary", button(src, SECONDARY, SECONDARY_CAPS, "button_secondary"))
