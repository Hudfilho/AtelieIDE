class_name ArenaPixelArt
extends RefCounted

## Sprites da arena desenhados como mapas de caracteres, virando texturas em
## tempo de execução. HUD discreto: uma cor só (HUD_COLOR) variando a opacidade.

const PIXEL := 4.0
const HUD_COLOR := Color("d6e6ee")
## Fontes bitmap do projeto (escala inteira): FONT em 22 = 2x, FONT_TINY em 16 = 2x.
const FONT: Font = preload("res://art/pixel/pixel_font.fnt")
const FONT_TINY: Font = preload("res://art/pixel/pixel_font_tiny.fnt")
const FONT_SIZE := 22
const FONT_TINY_SIZE := 16
## Cores das raridades (comum, rara, épica, lendária); rarity.gd usa as mesmas.
const RARITY_COLORS := [Color("d6e6ee"), Color("6ad1ff"), Color("c58cff"), Color("ffcf4a")]

static var _cache: Dictionary = {}


static func tint(alpha: float) -> Color:
	return Color(HUD_COLOR, alpha)


## rows: linhas de mesmo comprimento; palette: caractere -> Color. "." é transparente.
static func texture(key: String, rows: Array, palette: Dictionary) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var height := rows.size()
	var width := str(rows[0]).length()
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var row := str(rows[y])
		for x in range(width):
			var ch := row[x]
			if palette.has(ch):
				image.set_pixel(x, y, palette[ch])
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result


## Moldura de um pixel na cor do HUD, cantos recortados, fundo quase invisível.
static func draw_pixel_frame(canvas: CanvasItem, rect: Rect2, px := PIXEL) -> void:
	canvas.draw_rect(rect.grow(-px), Color(0.02, 0.04, 0.09, 0.55))
	var line := tint(0.75)
	canvas.draw_rect(Rect2(rect.position + Vector2(px, 0.0), Vector2(rect.size.x - px * 2.0, px)), line)
	canvas.draw_rect(Rect2(rect.position + Vector2(px, rect.size.y - px), Vector2(rect.size.x - px * 2.0, px)), line)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, px), Vector2(px, rect.size.y - px * 2.0)), line)
	canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x - px, px), Vector2(px, rect.size.y - px * 2.0)), line)


static func glass_palette(strength: float) -> Dictionary:
	return {"o": tint(0.85 * strength), "s": tint(0.6 * strength), "f": tint(0.06 * strength)}

const ORB := [
	"................",
	".....oooooo.....",
	"...ooffffffoo...",
	"..ooffffffffoo..",
	"..offssffffffo..",
	".offssffffffffo.",
	".offsfffffffffo.",
	".offffffffffffo.",
	".offffffffffffo.",
	".offffffffffffo.",
	".offfffffffsffo.",
	"..offfffffsffo..",
	"..ooffffffffoo..",
	"...ooffffffoo...",
	".....oooooo.....",
	"................",
]

const PLUS := [
	"..#..",
	"..#..",
	"#####",
	"..#..",
	"..#..",
]

const SHADOW := [
	"..######..",
	".########.",
	"..######..",
]

const STAND := [
	"............oooooooooooooooooooooooooooooooooooooooooooooooo............",
	"..........ooffffffffffffffffffffffffffffffffffffffffffffffffoo..........",
	"........ooffffffffffffffffffffffffffffffffffffffffffffffffffffoo........",
	"......ooffffffffffffffffffffffffffffffffffffffffffffffffffffffffoo......",
	"....ooffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffoo....",
	"..ooffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffoo..",
	"ooffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffoo",
	"oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo",
	"offffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffo",
	"offffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffo",
	"oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo",
]


static func orb_texture() -> ImageTexture:
	return texture("orb", ORB, glass_palette(1.0))

static func slot_texture() -> ImageTexture:
	return texture("slot", ORB, glass_palette(0.5))

static func plus_texture() -> ImageTexture:
	return texture("plus", PLUS, {"#": tint(0.8)})

static func shadow_texture() -> ImageTexture:
	return texture("shadow", SHADOW, {"#": tint(0.12)})

static func stand_texture() -> ImageTexture:
	return texture("stand", STAND, {"o": tint(0.55), "f": tint(0.07)})

static func spell_orb_texture(color: Color) -> ImageTexture:
	var palette := {"o": tint(0.9), "s": Color(1.0, 1.0, 1.0, 0.85), "f": Color(color, 0.62)}
	return texture("spell_orb_" + color.to_html(), ORB, palette)


## Disco alinhado à grade do pixel (linhas de px de altura). Com thickness > 0
## desenha só o anel, com essa espessura.
static func draw_pixel_disc(canvas: CanvasItem, center: Vector2, radius: float, color: Color, thickness := 0.0, px := PIXEL) -> void:
	if radius <= 0.0:
		return
	var c := Vector2(snappedf(center.x, px), snappedf(center.y, px))
	var inner := radius - thickness
	var y := -snappedf(radius, px)
	while y < radius:
		var mid := y + px * 0.5
		var half := snappedf(sqrt(maxf(radius * radius - mid * mid, 0.0)), px)
		if half > 0.0:
			if thickness <= 0.0 or inner <= 0.0 or absf(mid) >= inner:
				canvas.draw_rect(Rect2(c.x - half, c.y + y, half * 2.0, px), color)
			else:
				var inner_half := snappedf(sqrt(maxf(inner * inner - mid * mid, 0.0)), px)
				var band := maxf(half - inner_half, px)
				canvas.draw_rect(Rect2(c.x - half, c.y + y, band, px), color)
				canvas.draw_rect(Rect2(c.x + half - band, c.y + y, band, px), color)
		y += px
