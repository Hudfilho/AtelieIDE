---
tags: [editor, vm]
---
# 11 — Execução no editor (Play / Pause / Step / Stop)

Quem dirige a VM no editor é `scripts/atelier_canvas.gd` (≈4.600 linhas; concentra UI, desenho e execução). A parte que interessa ao compilador está em `_start_ritual`, `_execute_next_ritual_step` e `_finish_ritual`.

## Play

1. `compiler.compile(connections)` → IR + bytecode. Erros vão para o Oráculo e pintam células.
2. `RuneBytecode.decode(bytecode)` → instruções "limpas", **exatamente** o que um `.rune` exportado conteria.
3. Para cada instrução decodificada, copia `connection_index` e `intensity` da IR de mesma posição. É o que permite destacar a célula certa.
4. `vm.create_state()`, `state.memory = run_memory` (a bancada da loja usava isso para injetar entradas), `vm.configure_program(...)`.
5. Abre painéis de pilha e Oráculo e dispara o primeiro passo.

## Cada passo

```gdscript
vm.step(instruction, execution_state, instruction_index)
_refresh_execution_intensity_overrides()   # lê state.program e mostra a intensidade efetiva na célula
# novos itens em output/errors vão para o Oráculo
if jump_target >= 0: cursor = jump_target
if erro ou halted: _finish_ritual()
```

A velocidade é em **RPS** (runas por segundo), com `_advance_ritual(delta)` acumulando tempo. Pause congela; Step executa um passo manual; Stop chama `_finish_ritual(stopped = true)`.

## Sinal `ritual_finished(result)`

Emitido ao terminar, com `{ok, errors, output, stack, stopped}`. A bancada da loja escutava para comparar com o exemplo da encomenda. Um painel de "pilha mágica"/Castar deve escutar o mesmo sinal — ou ler o estado a cada passo — em vez de recompilar.

> [!warning] Intensidade efetiva ≠ intensidade desenhada
> `_refresh_execution_intensity_overrides` existe porque `INT_SET`/`INT_MOD` mudam `state.program`. O canvas mostra a intensidade *efetiva* por cima da célula enquanto o ritual roda, sem tocar no diagrama.
