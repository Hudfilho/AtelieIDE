class_name AtelierSettings
extends RefCounted

## Preferências do jogador, guardadas em user://settings.cfg: o idioma e o
## estilo de arte do balcão (este via AtelierDeskStyles). O idioma "" é o
## automático: o que o Godot escolheu ao abrir o jogo (o do sistema, ou o de
## teste do projeto), então nada força um idioma sem o jogador pedir.

## Idiomas oferecidos e a chave do nome de cada um ("" = automático).
const LANGUAGES := {"": "SETTINGS_LANGUAGE_AUTO", "en": "SETTINGS_LANGUAGE_EN", "pt_BR": "SETTINGS_LANGUAGE_PT_BR"}

## Arquivo das preferências; os testes trocam por um temporário.
static var path := "user://settings.cfg"
## Idioma escolhido pelo Godot ao abrir o jogo, guardado na primeira aplicação.
static var _boot_locale := ""


static func get_value(section: String, key: String, default: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return default
	return config.get_value(section, key, default)


static func set_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(path) # mantém as outras preferências, se houver
	config.set_value(section, key, value)
	config.save(path)


## Idioma salvo ("" = automático; um valor desconhecido também vale automático).
static func language() -> String:
	var code := str(get_value("game", "language", ""))
	return code if LANGUAGES.has(code) else ""


## Salva e aplica na hora. Textos com chave mudam sozinhos; o resto reage a
## NOTIFICATION_TRANSLATION_CHANGED.
static func set_language(code: String) -> void:
	set_value("game", "language", code)
	apply_language()


## Aplica o idioma salvo; a tela de título chama ao abrir o jogo.
static func apply_language() -> void:
	if _boot_locale.is_empty():
		_boot_locale = TranslationServer.get_locale()
	var code := language()
	TranslationServer.set_locale(code if not code.is_empty() else _boot_locale)
