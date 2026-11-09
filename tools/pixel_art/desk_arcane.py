"""Estilo "arcano" do balcão: loja mística com janela em arco, tapeçaria da
lua e bandeja de carimbos (assets em art/concepts/desk/arcane/).

- o fundo (backdrop.webp) já tem quase exatamente 640x360 "pixels de arte":
  basta reduzir por área. Os objetos que o fundo traz pintados e que o jogo
  desenha por cima (os pegadores da bandeja de carimbos, a beirada do
  pergaminho) são cobertos com textura do próprio fundo;
- objetos soltos (carimbos, bandeja, sino, vela, cartão do dia) são recortados
  do fundo liso e reduzidos;
- papéis com texto (pedido, nota, livro de regras) são remontados em fatias:
  cantos e bordas do asset em escala uniforme, miolo limpo (linhas pautadas
  apagadas) esticado até o tamanho que o texto do jogo precisa.
"""
from desk_art_common import *  # noqa: F401,F403 (funções de conversão)

FILES = StyleFiles("arcane")


def backdrop():
    src = FILES.load("backdrop")
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
    FILES.save(quantize(out, 200), "backdrop")



def stamps():
    src = FILES.load("stamps")
    for name, rect in (("stamp_approve", (250, 100, 290, 565)), ("stamp_reject", (720, 100, 290, 565))):
        object_sprites(FILES, quantize(fit_height(src, grabcut(src, rect), STAMP_HEIGHT), 48), name)
    # Frente da bandeja (poços de tinta e borda), no lugar da bandeja pintada no fundo.
    tray = src[655:1110, 40:1175]
    mask = flat_cutout(src)[655:1110, 40:1175]
    FILES.save(quantize(shrink(tray, mask, TRAY_SIZE), 48), "stamp_tray")



def bell():
    src = FILES.load("bell")
    object_sprites(FILES, quantize(fit_height(src, flat_cutout(src), BELL_SIZE), 32), "bell", flies=False)



def candle():
    src = FILES.load("candle")
    FILES.save(quantize(fit_height(src, flat_cutout(src), CANDLE_HEIGHT), 32), "candle")



def day_card():
    src = FILES.load("day_card")
    FILES.save(quantize(fit_width(src, flat_cutout(src), DAY_CARD_SIZE[0]), 48), "day_card")



REQUEST_SCALE = 0.16


def request():
    src = FILES.load("request")
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
    FILES.save(finish(canvas, REQUEST_SIZE), "parchment")



def note():
    """Bilhete preso com alfinete. O asset vem levemente girado e com sombra:
    o papel é endireitado (só o papel claro, sem a sombra) e esticado até o
    tamanho da nota. O alfinete do asset, nesse tamanho, vira borrão: é
    redesenhado com as cores de latão dos assets."""
    src = FILES.load("note")
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
    FILES.save(quantize(out, 48), "note")



BOOK_SCALE = 0.12
# Largura da pilha de folhas que sai de cada lado (colunas da fonte).
BOOK_STACK_CUT = 80
# Molduras das páginas (px do livro final): colunas de cada página e linhas.
BOOK_PAGE_FRAMES = ((10, 95), (106, 191))
BOOK_FRAME_Y = (9, 186)
BOOK_INK = (138, 92, 50, 255)


def book():
    src = FILES.load("rulebook")
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
