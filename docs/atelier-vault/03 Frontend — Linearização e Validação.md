---
tags: [frontend, compilador]
---
# 03 — Frontend: linearização e validação

`scripts/core/rune_compiler.gd` (`AtelierRuneCompiler.compile(connections)`) transforma a lista de conexões em instruções. É a análise **sintática** do Atelier: a sintaxe é a geometria.

## Passo a passo

1. **Componentes** — agrupa conexões que compartilham pontos (`_collect_component`). Cada componente é uma sequência candidata.
2. **Grau dos pontos** — um ponto com mais de 2 conexões do mesmo componente é **bifurcação** → erro `COMPILER_BRANCH`.
3. **Pontas** — toda sequência precisa de exatamente 2 pontos de grau 1. Zero pontas = círculo fechado → erro `COMPILER_SEQUENCE_ENDS`.
4. **Início** — a ponta com menor `x` (empate: menor `y`). As sequências são ordenadas entre si pelo mesmo critério (`_leftmost_sequence_entry`).
5. **Percurso** — caminha de ponta a ponta; cada célula com `symbol` vira uma instrução; células vazias são puladas.
6. **HALT implícito** — se a sequência não termina em `CROSS`, o compilador acrescenta `{"opcode": HALT, "implicit": true}` e emite um *warning*.
7. **Dependências** — `_validate_rune_dependencies` confere portais, `INT_SET`, `INT_MOD` (ver [[07 Portais e Saltos]] e [[08 INT_SET e INT_MOD]]).
8. **Limite** — mais de 65.535 instruções → `COMPILER_TOO_MANY`.

> [!warning] A ordem vem da topologia, não da criação
> O índice da conexão no array **não** define a ordem de execução. Só a posição das pontas define. Isso é uma decisão preservada do projeto.

## Múltiplas sequências

A primeira sequência (mais à esquerda) é a entrada do programa. As demais **não executam em cadeia**: cada uma termina em `HALT` e só é alcançada por `WARP`/`JUMP_IF_TRUE`. Loops existem via portais, não via círculos desenhados.

## Diagnósticos

Cada erro é um dicionário `{connection_index, code, message}`:
- `code` é a chave de tradução (`COMPILER_*`) — testes comparam o código.
- `message` já vem traduzida para o Oráculo.
- `connection_index` permite ao canvas pintar a célula de vermelho.

## Saída de `compile()`

```gdscript
{"ok": true, "instructions": [...], "bytecode": PackedByteArray, "errors": [], "warnings": [...], "diagnostics": []}
```

Próximo: [[04 Representação Intermediária (IR)]].
