class_name AtelierText
extends RefCounted

## Textos para o jogador vêm de chaves de tradução (localization/strings.csv,
## colunas en e pt_BR). Os valores usam % como no GDScript:
##   AtelierText.t("DESK_HUD_MONEY", [12])  ->  "12 coins"
## Um % literal num valor com argumentos precisa ser escrito como %%.

const DEFAULT_LOCALE := "en"


static func t(key: String, args: Array = []) -> String:
	var text := String(TranslationServer.translate(key))
	return text % args if not args.is_empty() else text
