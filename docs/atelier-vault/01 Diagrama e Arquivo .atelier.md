---
tags: [frontend, persistencia]
---
# 01 — Diagrama e arquivo `.atelier`

## O modelo de dados

O estado puro do desenho vive em `scripts/core/rune_diagram.gd` (`AtelierRuneDiagram`). Ele **não conhece UI** — só conexões, intensidades e histórico de undo/redo.

Cada **conexão** (célula) é um dicionário:

```gdscript
{ "from": Vector2, "to": Vector2, "symbol": "ORB", "intensity": 128 }
```

- `from`/`to` são pontos da grade (inteiros).
- `symbol` é o `kind` do catálogo, ou `""` para uma célula sem selo (ela é ignorada na compilação, mas conta na topologia).
- `intensity` ∈ [0, 255], padrão 128.

Operações do diagrama: `add_connection`, `append_connections`, `move_connections`, `move_anchor`, `remove_connections`, `set_symbol`, `set_intensity`, `undo`, `redo`. Todas gravam snapshot para o histórico.

> [!warning] Regras do traçado que o compilador assume
> O editor **bloqueia** bifurcações e círculos por nós ocupados na hora de desenhar. Mesmo assim, o compilador revalida isso (ver [[03 Frontend — Linearização e Validação]]), porque um `.atelier` editado à mão pode violar.

## O arquivo `.atelier`

`scripts/core/atelier_ritual_file.gd` salva e abre JSON:

```json
{
  "format": "atelier-rune",
  "version": 1,
  "pan": {"x": 340, "y": 230},
  "zoom": 1.0,
  "connections": [
    {"from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 0}, "symbol": "ORB", "intensity": 2}
  ]
}
```

Validações no `load_file`:
- `format` e `version` exatos; tamanho ≤ 8 MB; ≤ 20.000 conexões; coordenadas finitas e ≤ 10⁷.
- `symbol` desconhecido pelo catálogo → erro `FILE_UNKNOWN_RUNE`.
- `intensity` precisa ser inteiro em 0–255.

> [!info] Compatibilidade
> Adicionar runas novas ao catálogo **não** exige bump de versão: arquivos antigos continuam abrindo, e arquivos novos só falham em versões antigas da IDE com `FILE_UNKNOWN_RUNE`. Isso importa para [[14 Runas Mágicas — Mudanças para o Jogo]].

O `.atelier` é o **formato editável**. O bytecode (`.rune`) e o `.asm` são saídas — não se reabrem no editor.
