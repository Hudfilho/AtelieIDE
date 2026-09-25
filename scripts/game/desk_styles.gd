class_name AtelierDeskStyles
extends RefCounted

## Estilos de arte do balcão disponíveis e o preferido do jogador, guardado
## em user://settings.cfg (a escolha vale para as próximas partidas).
## Separado de AtelierDeskStyle para o script do recurso não citar a própria
## classe (isso cria um ciclo de referência que vaza ao fechar o jogo).

const STYLE_PATHS: Array[String] = ["res://data/desk_styles/arcane.tres", "res://data/desk_styles/apothecary.tres"]
const SECTION := "desk"
const KEY := "style"

## Arquivo das preferências; os testes trocam por um temporário.
static var settings_path := "user://settings.cfg"


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


## O estilo escolhido na tela de título, ou o primeiro se nada foi escolhido
## (ou se o escolhido não existe mais).
static func preferred() -> AtelierDeskStyle:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		var style := find(str(config.get_value(SECTION, KEY, "")))
		if style != null:
			return style
	return all()[0]


static func remember(style: AtelierDeskStyle) -> void:
	var config := ConfigFile.new()
	config.load(settings_path) # mantém as outras preferências, se houver
	config.set_value(SECTION, KEY, style.id)
	config.save(settings_path)
