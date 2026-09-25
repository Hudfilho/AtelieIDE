class_name AtelierDeskStyle
extends Resource

## Um estilo de arte do balcão: as texturas de fundo, papéis e objetos, e onde
## ficam as poucas peças que mudam de lugar (retrato e vela). O layout, os
## tamanhos dos papéis e o orçamento de texto são os mesmos em todos os
## estilos: as texturas de papel têm o tamanho dos papéis em Desk.tscn.
## Os sprites saem de tools/pixel_art/import_desk_art.py; os estilos
## disponíveis e o preferido ficam em AtelierDeskStyles.

@export var id := ""
## Chave de tradução do nome do estilo (tela de título).
@export var title_key := ""

@export_group("Cena")
## Fundo inteiro do balcão (640x360), com a janela do cliente pintada.
@export var backdrop: Texture2D
## Canto superior esquerdo do retrato (92x92), em px do palco: o busto se
## apoia no peitoril da janela pintada.
@export var portrait_position := Vector2(279, 38)
@export var candle: Texture2D
@export var candle_position := Vector2(224, 94)

@export_group("Papéis")
## Livro de regras aberto (202x212), pedido (244x212) e nota da inspeção (188x122).
@export var rulebook: Texture2D
@export var request: Texture2D
@export var note: Texture2D
## Cartão do dia na parede (88x123); os números ficam ao lado dos ícones.
@export var day_card: Texture2D

@export_group("Objetos")
@export var bell: Texture2D
@export var bell_lift: Texture2D
@export var stamp_approve: Texture2D
@export var stamp_approve_lift: Texture2D
## Cabeça que voa até o papel no carimbo.
@export var stamp_approve_head: Texture2D
@export var stamp_reject: Texture2D
@export var stamp_reject_lift: Texture2D
@export var stamp_reject_head: Texture2D
## Frente da bandeja ou almofadas de tinta (139x60), na frente dos carimbos.
@export var stamp_tray: Texture2D
