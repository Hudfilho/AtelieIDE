class_name AtelierPalette
extends RefCounted

## Paleta única do ateliê: ouro e tinta sobre couro à luz de vela.
##
## Cada tema é uma tabela de cores lida uma vez pela interface, que copia os
## valores para campos tipados. Assim o desenho por quadro não faz nenhuma
## busca por texto.

const DARK := {
	# Sala: madeira, couro e a luz das velas.
	"body_top": Color("1c150e"),
	"body_mid": Color("14100a"),
	"body_bottom": Color("0e0b07"),
	"candle_warm": Color(1.0, 0.588, 0.235, 0.10),
	"candle_gold": Color(0.902, 0.773, 0.416, 0.06),
	"grain": Color(0.784, 0.627, 0.353, 0.055),
	"vignette_outer": Color(0.0, 0.0, 0.0, 0.42),
	"vignette_warm": Color(0.157, 0.098, 0.031, 0.30),

	# Molduras de couro.
	"frame_top": Color("2c2116"),
	"frame_bottom": Color("241a12"),
	"frame_inner": Color(0.706, 0.541, 0.235, 0.25),
	"frame_sheen": Color(0.902, 0.773, 0.416, 0.12),
	"frame_shadow": Color(0.0, 0.0, 0.0, 0.50),
	"spellstrip": Color(0.706, 0.541, 0.235, 0.30),
	"ink_deep": Color("171a22"),

	# Latão e ouro.
	"brass": Color("8a6d3b"),
	"gold": Color("b48a3c"),
	"gold_bright": Color("d9b45c"),
	"gold_glow": Color("e6c56a"),
	"rune_line": Color("d9b45c"),
	"line_edge": Color("3d3319"),
	"leather_light": Color("3a2f1c"),
	"inset": Color(0.706, 0.541, 0.235, 0.10),
	"inset_deep": Color("1a140e"),

	# Texto.
	"text": Color("c9b590"),
	"text_faint": Color("8a7c5f"),
	"output": Color("e3cea2"),
	"warning": Color("d8c783"),
	"error": Color("ff8791"),
	"halt": Color("d46c4d"),
	"disabled": Color("6b5130"),
	"ember": Color("fff2b2"),
	"ember_soft": Color("ffe8a8"),

	# Céu do canvas.
	"sky": Color("0f1420"),
	"sky_high": Color("131a28"),
	"canvas_tint": Color(0.086, 0.125, 0.188, 0.267),
	"dot": Color(0.588, 0.667, 0.824, 0.18),
	"dot_hover": Color(0.784, 0.702, 0.431, 0.58),
	"star": Color("b48a3c"),
	"compass": Color(0.706, 0.541, 0.235, 0.28),

	# Medalhões de latão da paleta de selos.
	"seal_high": Color("3a2f1c"),
	"seal_low": Color("211812"),
	"seal_glyph": Color("e6c56a"),

	# Cartas de pergaminho do grimório.
	"parch_top": Color("d9c9a4"),
	"parch_bottom": Color("c7b487"),
	"parch_border": Color("7a6540"),
	"parch_dash": Color(0.353, 0.275, 0.157, 0.35),
	"parch_ink": Color("2a2013"),
	"parch_muted": Color("6a5533"),
	"parch_shadow": Color(0.0, 0.0, 0.0, 0.40),
	"sigil_high": Color("efe0bd"),
	"sigil_low": Color("cdb782"),
	"title_shadow": Color(0.0, 0.0, 0.0, 0.60),
}

const LIGHT := {
	"body_top": Color("efe4c8"),
	"body_mid": Color("e6d8b4"),
	"body_bottom": Color("dccaa0"),
	"candle_warm": Color(1.0, 0.745, 0.353, 0.20),
	"candle_gold": Color(0.784, 0.549, 0.196, 0.10),
	"grain": Color(0.361, 0.278, 0.118, 0.045),
	"vignette_outer": Color(0.588, 0.431, 0.196, 0.18),
	"vignette_warm": Color(0.471, 0.333, 0.118, 0.10),

	"frame_top": Color("f4ead0"),
	"frame_bottom": Color("e7d6b0"),
	"frame_inner": Color(0.588, 0.431, 0.196, 0.35),
	"frame_sheen": Color(1.0, 0.980, 0.922, 0.55),
	"frame_shadow": Color(0.290, 0.204, 0.078, 0.22),
	"spellstrip": Color(0.471, 0.353, 0.157, 0.35),
	"ink_deep": Color("171a22"),

	"brass": Color("8a6a34"),
	"gold": Color("9c6f22"),
	"gold_bright": Color("8a5d18"),
	"gold_glow": Color("b8862f"),
	"rune_line": Color("7c4f11"),
	"line_edge": Color("f0e4c7"),
	"leather_light": Color("c2ab7c"),
	"inset": Color(0.471, 0.353, 0.157, 0.10),
	"inset_deep": Color(0.471, 0.353, 0.157, 0.18),

	"text": Color("3a2c15"),
	"text_faint": Color("7a6231"),
	"output": Color("4a3718"),
	"warning": Color("8a6a1e"),
	"error": Color("a8322f"),
	"halt": Color("a8452a"),
	"disabled": Color("b0a184"),
	"ember": Color("c9721c"),
	"ember_soft": Color("e0912f"),

	"sky": Color("f6edd6"),
	"sky_high": Color("eaddb8"),
	"canvas_tint": Color(0.788, 0.710, 0.533, 0.133),
	"dot": Color(0.471, 0.373, 0.176, 0.28),
	"dot_hover": Color(0.427, 0.310, 0.098, 0.70),
	"star": Color("b8862f"),
	"compass": Color(0.588, 0.431, 0.196, 0.30),

	"seal_high": Color("e8d3a4"),
	"seal_low": Color("c6a86e"),
	"seal_glyph": Color("4a3410"),

	"parch_top": Color("f7efd8"),
	"parch_bottom": Color("e9dcba"),
	"parch_border": Color("a58a5c"),
	"parch_dash": Color(0.353, 0.275, 0.157, 0.30),
	"parch_ink": Color("3a2c15"),
	"parch_muted": Color("7a6231"),
	"parch_shadow": Color(0.290, 0.204, 0.078, 0.18),
	"sigil_high": Color("fdf6e2"),
	"sigil_low": Color("dfcda0"),
	"title_shadow": Color(1.0, 0.980, 0.922, 0.70),
}


static func table(theme_name: String) -> Dictionary:
	return LIGHT if theme_name == "light" else DARK
