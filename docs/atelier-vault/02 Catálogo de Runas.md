---
tags: [frontend, catalogo]
---
# 02 — Catálogo de runas

`scripts/core/rune_catalog.gd` (`AtelierRuneCatalog`) é a **tabela única** que interface, compilador, VM e exportador consultam. É o equivalente visual da análise léxica: dado um `kind`, devolve opcode e propriedades.

## Estrutura de um símbolo

```gdscript
{"kind": "ORB", "label": "PUSH", "description": "RUNE_ORB_DESC", "extra": "RUNE_ORB_EXTRA",
 "opcode": OPCODE_PUSH, "takes_operand": true, "result_type": "int"}
```

- `takes_operand`: a intensidade também é o operando (número, endereço, id de portal, letra).
- `result_type: "int"`: a runa deixa um inteiro novo no topo. **É isso que a torna uma "produtora"** para `INT_SET` (ver [[08 INT_SET e INT_MOD]]).

Listas auxiliares usadas pelo compilador/backends:
- `BINARY_OPCODES` — consomem 2, produzem 1.
- `INTENSITY_OPERATIONS` — operações válidas para `INT_MOD` (`ADD SUB MUL DIV MOD NEG`).
- `STACK_READ_OPCODES`, `STACK_PUSH_OPCODES` — alimentam `required_stack_depth()` e `stack_delta()`, que a análise estática do NASM usa.

## As 30 runas

| kind | label | opcode | operando | produz int | efeito na pilha |
|---|---|---|---|---|---|
| ORB | PUSH | 0x01 | sim | sim | +1 |
| CUP | DROP | 0x09 | | | −1 |
| TWIN | DUP | 0x0a | | sim | +1 |
| KNOT | SWAP | 0x0b | | | 0 (precisa 2) |
| DIAMOND | ADD | 0x02 | | sim | −1 |
| MOON | SUB | 0x03 | | sim | −1 |
| PLUS | MUL | 0x04 | | sim | −1 |
| SLASH | DIV | 0x0c | | sim | −1 |
| SPIRAL | MOD | 0x0d | | sim | −1 |
| DASH | NEG | 0x0e | | sim | 0 |
| EQ / NEQ / LT / GT / LTE / GTE | idem | 0x12–0x17 | | sim | −1 |
| NOT | NOT | 0x18 | | sim | 0 |
| AND / OR | idem | 0x19 / 0x1a | | sim | −1 |
| WARP | WARP | 0x0f | sim (id) | | 0 |
| WARP_ENDPOINT | WARP END | 0x1b | sim (id) | | 0 |
| JUMP_IF_TRUE | JUMP_IF_TRUE | 0x1d | sim (id) | | 0 (lê topo) |
| INT_MOD | INT_MOD | 0x10 | | | 0 |
| INT_SET | INT_SET | 0x11 | | | 0 |
| TRIANGLE | PRINT | 0x05 | | | 0 (lê topo) |
| PRINTLETTER | PRINTLETTER | 0x1c | sim (char) | | 0 |
| CROSS | HALT | 0x06 | | | 0 |
| SQUARE | STORE | 0x07 | sim (slot) | | −1 |
| FORK | LOAD | 0x08 | sim (slot) | sim | +1 |
| READ | READ | 0x1e | sim (slot) | sim | +1 |

> [!warning] Ao adicionar runas
> - Nunca reaproveite um opcode: arquivos `.rune` antigos dependem deles. Opcodes livres começam em `0x1f`.
> - Só declare `result_type: "int"` se a runa **realmente** deixa um inteiro no topo da pilha numérica; caso contrário `INT_SET` vai consumir um valor errado.
> - O exportador NASM tem sua própria lista `SUPPORTED_OPCODES`; uma runa nova fora dela deve ser **rejeitada com mensagem**, não ignorada.
