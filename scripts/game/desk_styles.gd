class_name AtelierDeskStyles
extends RefCounted

## Estilos de arte do balcão disponíveis e o preferido do jogador, guardado
## nas preferências (AtelierSettings) e escolhido nas configurações.
## Separado de AtelierDeskStyle para o script do recurso não citar a própria
## classe (isso cria um ciclo de referência que vaza ao fechar o jogo).

const STYLE_PATHS: Array[String] = ["res://data/desk_styles/arcane.tres", "res://data/desk_styles/apothecary.tres"]
const SECTION := "desk"
const KEY := "style"


static func all() -> Array[AtelierDeskStyle]:
	var styles: Array[AtelierDeskStyle] = []
	for path in STYLE_PATHS:
		styles.append(load(path) as AtelierDeskStyle)
	return styles


static func find(style_id: String) -> AtelierDeskStyle:
	for style in all():
		if style.id == style_id:
			return style
	return null


## O estilo escolhido, ou o primeiro se nada foi escolhido (ou se o escolhido
## não existe mais).
static func preferred() -> AtelierDeskStyle:
	var style := find(str(AtelierSettings.get_value(SECTION, KEY, "")))
	return style if style != null else all()[0]


static func remember(style: AtelierDeskStyle) -> void:
	AtelierSettings.set_value(SECTION, KEY, style.id)
