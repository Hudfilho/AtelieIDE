class_name AtelierPortrait
extends Resource

## Retrato de um cliente na janela do balcão, com uma expressão por humor.
## O balcão escolhe o humor pelo que acontece (reação ao carimbo, paciência na
## inspeção); expressões que faltam caem na neutra. Os PNGs vêm de
## tools/pixel_art/make_portraits.py (92x92, pixel art, fundo transparente).

enum Mood { NEUTRAL, HAPPY, UNEASY, UPSET }

## Quem é (para ferramentas e testes); não aparece no jogo.
@export var character := ""
@export var neutral: Texture2D
## Carimbo aprovado.
@export var happy: Texture2D
## Primeiros sinais de impaciência na inspeção.
@export var uneasy: Texture2D
## Impaciência no limite ou pedido recusado.
@export var upset: Texture2D


func texture_for(mood: Mood) -> Texture2D:
	var picked: Texture2D = [neutral, happy, uneasy, upset][mood]
	return picked if picked != null else neutral
