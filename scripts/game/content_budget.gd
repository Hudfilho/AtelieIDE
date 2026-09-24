class_name AtelierContentBudget
extends RefCounted

## Orçamento de texto do balcão em pixel art (640x360). Mede as linhas como o
## balcão desenha (mesma fonte, quebra de linha e larguras). Conteúdo acima
## do orçamento é INVÁLIDO: a fonte nunca encolhe e o layout não muda sozinho;
## reescreva o texto (ou mude o layout de propósito).

const FONT_PATH := "res://art/pixel/pixel_font.fnt"
const FONT_SIZE := 11
const LINE_HEIGHT := 12
const TITLE_FONT_PATH := "res://art/pixel/pixel_font_title.fnt"
const TITLE_FONT_SIZE := 13
## Linha da fonte miúda (números das regras e cabeçalhos).
const TINY_LINE_HEIGHT := 9

const TITLE_MAX_LINES := 1
const DETAILS_MAX_CHARS := 150
const DETAILS_MAX_LINES := 4
const SPEC_MAX_LINES := 2
const SPEECH_MAX_LINES := 3
const RULES_MAX_VISIBLE := 3

## Larguras de texto no layout atual do balcão (px do balcão). O teste
## content_budget_smoke confere que batem com o que a cena desenha.
const TITLE_WIDTH := 218.0
const DETAILS_WIDTH := 218.0
const SPEC_WIDTH := 222.0
const SPEECH_WIDTH := 172.0
const RULE_WIDTH := 76.0
## Livro aberto: altura útil de cada página, o cabeçalho de cada página
## (título à esquerda, florão à direita: linha miúda + espaço) e o espaço
## entre regras.
const RULES_PAGE_HEIGHT := 185.0
const RULES_TITLE_HEIGHT := 13.0
const RULE_SEPARATION := 6.0
## Folga de 1 px sob cada campo e regra, onde cai o sublinhado da seleção.
const FIELD_UNDERLINE := 1.0
## Prefixo de prova que uma regra ou os detalhes podem receber.
const EVIDENCE_PREFIX := "» "

static var _fonts := {}


static func rendered_lines(text: String, width: float, font_path := FONT_PATH, font_size := FONT_SIZE) -> int:
	if not _fonts.has(font_path):
		_fonts[font_path] = load(font_path)
	var paragraph := TextParagraph.new()
	paragraph.width = width
	# Mesma quebra dos Label/Button com autowrap WORD_SMART.
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, _fonts[font_path], font_size)
	return paragraph.get_line_count()


## Problemas de orçamento de uma encomenda. O texto dela não é traduzido, e o
## balcão não põe rótulo traduzido na mesma linha, então basta medir uma vez.
static func check_order(order: AtelierScrollOrder) -> PackedStringArray:
	var problems: PackedStringArray = []
	var title_lines := rendered_lines(order.item, TITLE_WIDTH, TITLE_FONT_PATH, TITLE_FONT_SIZE)
	if title_lines > TITLE_MAX_LINES:
		problems.append("%s title takes %d lines (max %d): %s" % [order.id, title_lines, TITLE_MAX_LINES, order.item])
	if order.details.length() > DETAILS_MAX_CHARS:
		problems.append("%s: details has %d characters (max %d)" % [order.id, order.details.length(), DETAILS_MAX_CHARS])
	# Pior caso: os detalhes citados como prova ganham o prefixo.
	_limit(problems, "%s details" % order.id, EVIDENCE_PREFIX + order.details, DETAILS_WIDTH, DETAILS_MAX_LINES)
	_limit(problems, "%s scroll requirement" % order.id, order.spec.get_slice("\n", 0), SPEC_WIDTH, SPEC_MAX_LINES)
	for line in [order.greeting, order.reaction_approved, order.reaction_refused]:
		if not line.is_empty():
			_limit(problems, "%s speech" % order.id, "\"%s\"" % line, SPEECH_WIDTH, SPEECH_MAX_LINES)
	return problems


## Problemas de um dia: regras visíveis ao mesmo tempo, capacidade de cada
## página do livro e todas as versões de todos os clientes.
static func check_day(day: AtelierShopDay) -> PackedStringArray:
	var problems: PackedStringArray = []
	if day.rules.size() > RULES_MAX_VISIBLE:
		problems.append("%s: %d rules in force, the rulebook shows at most %d" % [day.title, day.rules.size(), RULES_MAX_VISIBLE])
	var pages := rule_pages(day.rules)
	for index in pages.size():
		var height := page_height(pages[index])
		if height > RULES_PAGE_HEIGHT:
			problems.append("%s: rules need %d px of rulebook page %d, it has %d" % [day.title, int(height), index + 1, int(RULES_PAGE_HEIGHT)])
	for slot in day.orders:
		for order in AtelierShopDay.versions_of(slot):
			problems.append_array(check_order(order))
	return problems


## Divisão das regras no livro aberto: a página esquerda leva a primeira
## metade (arredondada para cima), a direita o resto. O balcão usa a mesma.
static func rule_pages(rules: Array[AtelierShopRule]) -> Array[Array]:
	var split := ceili(rules.size() / 2.0)
	return [rules.slice(0, split), rules.slice(split)]


## Altura que as regras ocupam numa página; por padrão no pior caso (todas
## citadas, com o prefixo de prova). Cada regra tem uma linha miúda com o
## número e o texto embaixo.
static func page_height(rules: Array, prefix := EVIDENCE_PREFIX) -> float:
	var height := RULES_TITLE_HEIGHT
	for rule: AtelierShopRule in rules:
		height += TINY_LINE_HEIGHT + rendered_lines(prefix + rule.text, RULE_WIDTH) * LINE_HEIGHT + FIELD_UNDERLINE
	return height + maxi(rules.size() - 1, 0) * RULE_SEPARATION


static func _limit(problems: PackedStringArray, what: String, text: String, width: float, max_lines: int) -> void:
	var lines := rendered_lines(text, width)
	if lines > max_lines:
		problems.append("%s takes %d lines (max %d): %s" % [what, lines, max_lines, text.left(60)])
