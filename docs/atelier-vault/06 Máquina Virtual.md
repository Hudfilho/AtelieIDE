---
tags: [backend, vm]
---
# 06 — Máquina virtual

`scripts/core/rune_vm.gd` (`AtelierRuneVM`). Máquina de pilha mínima, projetada para rodar **passo a passo** dentro do editor.

## Estado (`create_state()`)

```gdscript
{
  "stack": [],              # pilha numérica (int 64 bits)
  "memory": {},             # slot (0..255) -> int
  "output": [],             # strings emitidas por PRINT/PRINTLETTER
  "errors": [],
  "halted": false,
  "jump_target": -1,        # próximo pc, se houve salto
  "warp_targets": {}, "jump_if_true_targets": {}, "warp_endpoint_counts": {},
  "program": [],            # cópia MUTÁVEL das instruções
  "pending_int_set": -1,
}
```

## Duas formas de usar

**`run(bytecode, initial_memory = {}, max_steps = 10000)`** — decodifica, configura e roda em loop. Usada por testes, ferramentas e pelo juiz da loja. Devolve `{ok, errors, output, stack, steps, timed_out}`. `initial_memory` é como uma encomenda entrega parâmetros para `READ`/`LOAD`.

**`configure_program(state, instructions)` + `step(instruction, state, index)`** — o chamador (o canvas) mantém o `pc` e chama `step` por instrução. É assim que Play/Pause/Step funcionam. Ver [[11 Execução no Editor (Play)]].

## Semântica que precisa ser preservada

| Runa | Comportamento |
|---|---|
| `PRINT` | Lê o topo **sem remover**; não adiciona espaço nem `\n`. |
| `STORE n` | **Remove** o topo e grava em `memory[n]`. |
| `LOAD n` / `READ n` | Empilham `memory[n]`; slot vazio é erro. `READ` **não** lê teclado. |
| Comparações | Produzem `0` ou `1`. |
| `NOT`/`AND`/`OR` | Exigem exatamente 0/1; outro valor é erro. |
| `JUMP_IF_TRUE` | Testa se topo `== 1`, **não remove**. |
| `DIV`/`MOD` por zero | Erro. `DIV` trunca para zero (`int(left / right)`). |
| `PRINTLETTER n` | `String.chr(n)`; `0` vira U+FFFD. |
| `HALT` | Para. Qualquer erro também para (`halted = true`). |

## Por que `program` é mutável

`INT_SET`/`INT_MOD` reescrevem a intensidade de instruções **na cópia em execução** (`_set_instruction_intensity`). Depois chamam `configure_program` de novo para recalcular os destinos dos portais — porque um portal pode ter mudado de id. O ritual salvo nunca é alterado. Detalhes em [[08 INT_SET e INT_MOD]].

## Limite de passos

`run()` tem `max_steps` (padrão 10.000) e marca `timed_out`. O Play incremental **não** aplica esse limite global — um loop infinito no editor roda até o usuário parar.
