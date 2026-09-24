class_name AtelierContentBudget
extends RefCounted

## Orçamento de texto do balcão em pixel art (640x360). Mede as linhas como o
## balcão desenha (mesma fonte, quebra de linha e larguras) em todos os idiomas
## carregados. Conteúdo acima do orçamento é INVÁLIDO: a fonte nunca encolhe e
## o layout não muda sozinho; reescreva o texto (ou mude o layout de propósito).

const FONT_PATH := "res://art/pixel/pixel_font.fnt"
const FONT_SIZE := 11
const LINE_HEIGHT := 12

const DETAILS_MAX_CHARS := 150
const DETAILS_MAX_LINES := 4
const SPEC_MAX_LINES := 2
const SPEECH_MAX_LINES := 3
const RULES_MAX_VISIBLE := 3

## Larguras de texto no layout atual do balcão (px do balcão). O teste
## content_budget_smoke confere que batem com o que a cena desenha.
const DETAILS_WIDTH := 212.0
const SPEC_WIDTH := 216.0
const SPEECH_WIDTH := 206.0
const RULE_WIDTH := 118.0
## Altura útil da página do livro de regras abaixo do título, e o espaço entre regras.
const RULES_PAGE_HEIGHT := 187.0
const RULE_SEPARATION := 6.0
## Prefixo mais largo que uma regra pode receber no livro ("- " ou "» ").
const RULE_PREFIX := "» "

static var _font: Font


static func rendered_lines(text: String, width: float) -> int:
	if _font == null:
		_font = load(FONT_PATH)
	var paragraph := TextParagraph.new()
	paragraph.width = width
	# Mesma quebra dos Label/Button com autowrap WORD_SMART.
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, _font, FONT_SIZE)
	return paragraph.get_line_count()


## Problemas de orçamento de uma encomenda, em todos os idiomas carregados.
static func check_order(order: AtelierScrollOrder) -> PackedStringArray:
	var problems: PackedStringArray = []
	if order.details.length() > DETAILS_MAX_CHARS:
		problems.append("%s: details has %d characters (max %d)" % [order.id, order.details.length(), DETAILS_MAX_CHARS])
	var speech: PackedStringArray = [order.greeting]
	for line in [order.reaction_approved, order.reaction_refused]:
		if not line.is_empty():
			speech.append(line)
	for locale in TranslationServer.get_loaded_locales():
		var details := _message(locale, "DESK_FIELD_DETAILS") % [order.details]
		_limit(problems, "%s [%s] details" % [order.id, locale], details, DETAILS_WIDTH, DETAILS_MAX_LINES)
		var spec := _message(locale, "DESK_SCROLL_MUST") % [order.spec.get_slice("\n", 0)]
		_limit(problems, "%s [%s] scroll requirement" % [order.id, locale], spec, SPEC_WIDTH, SPEC_MAX_LINES)
		for line in speech:
			_limit(problems, "%s [%s] speech" % [order.id, locale], "\"%s\"" % line, SPEECH_WIDTH, SPEECH_MAX_LINES)
	return problems


## Problemas de um dia: regras visíveis ao mesmo tempo, capacidade da página
## do livro e todas as versões de todos os clientes.
static func check_day(day: AtelierShopDay) -> PackedStringArray:
	var problems: PackedStringArray = []
	if day.rules.size() > RULES_MAX_VISIBLE:
		problems.append("%s: %d rules in force, the rulebook page shows at most %d" % [day.title, day.rules.size(), RULES_MAX_VISIBLE])
	var height := rules_page_height(day.rules)
	if height > RULES_PAGE_HEIGHT:
		problems.append("%s: rules need %d px of the rulebook page, it has %d" % [day.title, int(height), int(RULES_PAGE_HEIGHT)])
	for slot in day.orders:
		for order in AtelierShopDay.versions_of(slot):
			problems.append_array(check_order(order))
	return problems


## Altura que as regras ocupam na página, no pior caso (prefixo de prova).
static func rules_page_height(rules: Array[AtelierShopRule]) -> float:
	var lines := 0
	for rule in rules:
		lines += rendered_lines(RULE_PREFIX + rule.text, RULE_WIDTH)
	return lines * LINE_HEIGHT + maxi(rules.size() - 1, 0) * RULE_SEPARATION


static func _limit(problems: PackedStringArray, what: String, text: String, width: float, max_lines: int) -> void:
	var lines := rendered_lines(text, width)
	if lines > max_lines:
		problems.append("%s takes %d lines (max %d): %s" % [what, lines, max_lines, text.left(60)])


static func _message(locale: String, key: String) -> String:
	return String(TranslationServer.get_translation_object(locale).get_message(key))
