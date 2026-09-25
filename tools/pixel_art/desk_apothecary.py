"""Estilo "botica" do balcão: parede de tábuas com ervas e prateleiras, janela
retangular e balcão liso (assets em art/concepts/desk/apothecary/).

Os objetos já vêm com fundo transparente, então o recorte é o próprio alfa.
O fundo foi pintado com o balcão mais baixo que o layout do jogo: a parede
sobe (o sol da janela cai no mesmo lugar do estilo arcano, onde os retratos,
a vela e o sino se apoiam), o lambri sob a janela sai e as tábuas do balcão
se repetem até o pé da tela.
"""
from desk_art_common import *  # noqa: F401,F403 (funções de conversão)

FILES = StyleFiles("apothecary")

# Linhas do fundo reduzido a 640x360 (medidas no asset).
WALL_SHIFT = 23          # a parede sobe isso: o peitoril (y 152) cai no y 129
SILL_BOTTOM = 164        # fim do peitoril; daqui até o balcão é lambri
SHADOW_ROWS = 4          # linhas de sombra do lambri mantidas sob o peitoril
COUNTER_TOP = 188        # início do tampo do balcão
PLANKS = (212, 287)      # trecho de tábuas que se repete para baixo

INK = (150, 102, 50, 255)


def alpha_mask(rgba, threshold=128):
    return (rgba[..., 3] >= threshold).astype(np.uint8)


def backdrop():
    src = FILES.load("backdrop")
    img = np.array(Image.fromarray(src).resize(BACKDROP_SIZE, Image.BOX))
    wall = img[WALL_SHIFT:SILL_BOTTOM + SHADOW_ROWS]
    counter = img[COUNTER_TOP:PLANKS[1]]
    planks = img[PLANKS[0]:PLANKS[1]]
    rows = [wall, counter]
    height = wall.shape[0] + counter.shape[0]
    while height < BACKDROP_SIZE[1]:
        rows.append(planks)
        height += planks.shape[0]
    out = np.concatenate(rows)[:BACKDROP_SIZE[1]]
    FILES.save(quantize(Image.fromarray(np.ascontiguousarray(out)).convert("RGBA"), 200), "backdrop")


# ======================================================================
# Objetos soltos (fundo transparente)
# ======================================================================
def cut(rgba, box):
    x0, y0, x1, y1 = box
    piece = rgba[y0:y1, x0:x1]
    return piece[..., :3], largest(alpha_mask(piece))


def stamps():
    src = FILES.load_rgba("stamps")
    scale = None
    pads = []
    for name, stamp_box, pad_box in (("stamp_approve", (120, 140, 620, 780), (60, 780, 640, 1100)),
                                     ("stamp_reject", (640, 140, 1140, 780), (620, 780, 1200, 1100))):
        rgb, mask = cut(src, stamp_box)
        crop, m = crop_to(rgb, mask)
        scale = STAMP_HEIGHT / crop.shape[0]
        head = quantize(shrink(crop, m, (round(crop.shape[1] * scale), STAMP_HEIGHT)), 48)
        object_sprites(FILES, head, name)
        rgb, mask = cut(src, pad_box)
        crop, m = crop_to(rgb, mask)
        pads.append(quantize(shrink(crop, m, (round(crop.shape[1] * scale), round(crop.shape[0] * scale))), 32))
    # "Bandeja": as duas almofadas de tinta, uma na frente de cada carimbo
    # (centros dos carimbos a 44 e 99 px da esquerda da bandeja, ver Desk.tscn).
    tray = Image.new("RGBA", TRAY_SIZE, (0, 0, 0, 0))
    for pad, center in zip(pads, (44, 99)):
        tray.alpha_composite(pad, (center - pad.width // 2, 8))
    FILES.save(tray, "stamp_tray")


def bell():
    src = FILES.load_rgba("bell")
    rgb, mask = cut(src, (0, 0, src.shape[1], src.shape[0]))
    object_sprites(FILES, quantize(fit_height(rgb, mask, BELL_SIZE), 32), "bell", flies=False)


def candle():
    src = FILES.load_rgba("candle")
    rgb, mask = cut(src, (0, 0, src.shape[1], src.shape[0]))
    FILES.save(quantize(fit_height(rgb, mask, CANDLE_HEIGHT), 32), "candle")


def day_card():
    """Cartão do dia. As palavras pintadas no asset (Day, Coins...) saem: o
    jogo escreve os números traduzidos ao lado dos ícones."""
    src = FILES.load_rgba("day_card")
    rgb = src[..., :3].copy()
    words = rect_mask(rgb.shape, [(330, 470, 700, 580), (330, 670, 700, 780), (330, 860, 700, 970), (330, 1050, 700, 1160)])
    rgb = erase_ink(rgb, words, threshold=30, grow=4)
    card, mask = crop_to(rgb, largest(alpha_mask(src)))
    height = round(card.shape[0] * DAY_CARD_SIZE[0] / card.shape[1])
    small = quantize(shrink(card, mask, (DAY_CARD_SIZE[0], height)), 48)
    out = Image.new("RGBA", DAY_CARD_SIZE, (0, 0, 0, 0))
    out.alpha_composite(small, (0, 0))
    FILES.save(out, "day_card")


# ======================================================================
# Papéis
# ======================================================================
def plain_paper(rgba, threshold=14):
    """Pergaminho sem os traços finos de tinta (linhas, moldura). Os enfeites
    grandes não são apagados: a montagem só usa trechos onde eles não estão."""
    mask = largest(alpha_mask(rgba))
    inside = cv2.erode(mask, np.ones((61, 61), np.uint8)).astype(bool)
    rgb = erase_ink(rgba[..., :3].copy(), inside, threshold=threshold, grow=4)
    return with_alpha(rgb, mask)


def ink_piece(rgba, box, darker=30):
    """Recorta um enfeite (lua, estrela) só com a tinta, sem o papel em volta:
    tinta é o que fica bem mais escuro que o papel claro do recorte."""
    x0, y0, x1, y1 = box
    rgb = np.ascontiguousarray(rgba[y0:y1, x0:x1, :3])
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.int16)
    ink = gray < np.percentile(gray, 90) - darker
    return rgb, ink.astype(np.uint8)


def draw_frame(img, box, color=INK):
    """Moldura de 1 px (só sobre o papel)."""
    x0, y0, x1, y1 = box
    hline(img, x0, x1, y0, color)
    hline(img, x0, x1, y1, color)
    px = img.load()
    for y in range(y0, y1 + 1):
        for x in (x0, x1):
            if px[x, y][3]:
                px[x, y] = color


def hline(img, x0, x1, y, color=INK):
    px = img.load()
    for x in range(x0, x1 + 1):
        if px[x, y][3]:
            px[x, y] = color


REQUEST_SCALE = 0.16


def request():
    """Pedido: beirada rasgada e cantos dobrados do asset; o miolo vem de uma
    faixa limpa entre a caixa do título e a primeira linha pautada. A moldura
    é redesenhada a 1 px, com a lua do asset no meio da linha de cima
    (reduzida para caber na margem de cima do texto) e estrelas nas laterais."""
    src = FILES.load_rgba("request")
    paper = plain_paper(src)
    target = (round(REQUEST_SIZE[0] / REQUEST_SCALE), round(REQUEST_SIZE[1] / REQUEST_SCALE))
    canvas = compose(paper, (24, 150, 930, 1052), (36, 140, 1300, 1410), target,
                     side_rows=(600, 700), cap_cols=(250, 380), center=(150, 430, 930, 495), outer=60)
    out = finish(canvas, REQUEST_SIZE)
    frame = (9, 9, REQUEST_SIZE[0] - 11, REQUEST_SIZE[1] - 10)
    draw_frame(out, frame)
    moon_rgb, moon_ink = ink_piece(src, (478, 135, 600, 262))
    moon = shrink(moon_rgb, moon_ink, (15, 16))
    cx = (REQUEST_SIZE[0] - moon.width) // 2
    px = out.load()
    for x in range(cx - 2, cx + moon.width + 2):
        px[x, frame[1]] = px[x, frame[1] + 3]
    out.alpha_composite(moon, (cx, 1))
    star_rgb, star_ink = ink_piece(src, (78, 425, 135, 490))
    star = shrink(star_rgb, star_ink, (7, 8))
    for x in (frame[0] - 3, frame[2] - 3):
        out.alpha_composite(star, (x, REQUEST_SIZE[1] // 2 - 4))
    FILES.save(out, "parchment")


NOTE_SCALE = 0.14


def note():
    """Bilhete: papel do asset remontado no formato da nota, sem as linhas; o
    alfinete é a tacha de latão desenhada (a do asset vira borrão pequena)."""
    src = FILES.load_rgba("note")
    paper = plain_paper(src)
    target = (round(NOTE_SIZE[0] / NOTE_SCALE), round((NOTE_SIZE[1] - 3) / NOTE_SCALE))
    canvas = compose(paper, (80, 280, 800, 1010), (240, 420, 1080, 1270), target,
                     side_rows=(560, 720), cap_cols=(640, 760), center=(300, 480, 780, 1000), outer=60)
    body = finish(canvas, (NOTE_SIZE[0], NOTE_SIZE[1] - 3), 48)
    out = Image.new("RGBA", NOTE_SIZE, (0, 0, 0, 0))
    out.alpha_composite(body, (0, 3))
    out.alpha_composite(pushpin(), ((NOTE_SIZE[0] - 9) // 2, 0))
    FILES.save(out, "note")


BOOK_SCALE = 0.166
# Enfeites das páginas (px do livro final): como no asset, uma linha em cima e
# outra embaixo de cada página, com estrelas nas pontas e no meio. As páginas
# deste livro vão até a beirada do texto, então não há linhas laterais.
BOOK_PAGES = ((16, 90), (111, 185))
BOOK_LINES_Y = (8, 187)
BOOK_INK = (170, 120, 58, 255)


def book():
    src = FILES.load_rgba("rulebook")
    mask = largest(alpha_mask(src))
    pages = rect_mask(src.shape, [(100, 170, 600, 900), (660, 170, 1160, 900)])
    rgb = erase_ink(src[..., :3].copy(), pages, threshold=12, grow=4)
    rgba = with_alpha(rgb, mask)
    seam = 627
    half_w = round(BOOK_SIZE[0] / 2 / BOOK_SCALE)
    body_h = round((BOOK_SIZE[1] - 12) / BOOK_SCALE)
    left = compose(rgba, (20, 200, 440, seam), (125, 300, 800, 990), (half_w, body_h),
                   side_rows=(450, 620), cap_cols=(250, 330), center=(220, 330, 500, 760))
    canvas = np.zeros((round(BOOK_SIZE[1] / BOOK_SCALE), half_w * 2, 4), np.uint8)
    canvas[:body_h, :half_w] = left
    canvas[:body_h, half_w:] = np.ascontiguousarray(left[:, ::-1])
    full = with_alpha(src[..., :3], mask)
    # Fechos de latão nas laterais (a 1/3 e 2/3 da altura), a capa da lombada
    # em cima, a argola embaixo e a fita marcadora.
    for box, at_right in (((22, 340, 70, 420), False), ((1190, 340, 1240, 420), True)):
        clasp = full[box[1]:box[3], box[0]:box[2]]
        for frac in (0.33, 0.66):
            x = canvas.shape[1] - clasp.shape[1] if at_right else 0
            paste(canvas, clasp, x, round(body_h * frac) - clasp.shape[0] // 2)
    cap = full[140:210, 580:680]
    paste(canvas, cap, half_w - cap.shape[1] // 2, 0)
    ring = full[930:1020, 570:690]
    paste(canvas, ring, half_w - ring.shape[1] // 2, body_h - 60)
    ribbon = full[940:1140, 670:770]
    paste(canvas, ribbon, half_w + 30, body_h - 50)
    spread = finish(canvas, BOOK_SIZE)
    star_rgb, star_ink = ink_piece(src, (128, 182, 178, 236))
    star = shrink(star_rgb, star_ink, (7, 8))
    for x0, x1 in BOOK_PAGES:
        for y in BOOK_LINES_Y:
            hline(spread, x0 + 4, x1 - 4, y, BOOK_INK)
            for sx in (x0, (x0 + x1) // 2, x1):
                spread.alpha_composite(star, (sx - 3, y - 4))
    FILES.save(spread, "book_spread")


def build():
    backdrop()
    stamps()
    bell()
    candle()
    day_card()
    request()
    note()
    book()
