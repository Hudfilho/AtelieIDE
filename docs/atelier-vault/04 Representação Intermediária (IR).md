---
tags: [compilador, ir]
---
# 04 — Representação intermediária (IR)

A IR do Atelier é **uma lista linear de dicionários**. Não há árvore: a linguagem é sequencial com saltos, então uma lista com índices é suficiente.

```gdscript
{
  "opcode": 1,            # PUSH
  "intensity": 128,       # sempre presente, 0..255
  "operand": 128,         # só se takes_operand; igual à intensidade
  "connection_index": 0,  # célula de origem no desenho
  "sequence_index": 0     # qual sequência gerou a instrução
}
```

Instruções sintéticas (HALT implícito) têm `"implicit": true` e **não** têm `connection_index`.

## Para que servem os campos de origem

- `connection_index` → destaque da célula em execução e marcação de erro no canvas. **Não entra no bytecode.**
- `sequence_index` → o validador usa `_same_sequence_rune()` para garantir que `INT_MOD` e `INT_SET` encontram operação/alvo **dentro da mesma sequência**, sem atravessar um `HALT`.

## IR → duas saídas

| Destino | Função | Perde origem? |
|---|---|---|
| Bytecode RUNE | `RuneBytecode.encode(instructions)` | Sim — só opcode + intensidade |
| NASM | `AtelierRuneNasmExporter.generate(connections)` | Recompila internamente; usa índices para rótulos |

> [!info] O Play recoloca a origem
> No editor, o Play **decodifica o bytecode** e depois copia `connection_index`/`intensity` da IR de volta para cada instrução decodificada, posição a posição. Assim a VM roda o mesmo bytecode que seria exportado, mas o canvas ainda sabe qual célula destacar. Ver [[11 Execução no Editor (Play)]].
