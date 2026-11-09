---
tags: [backend, nasm]
---
# 10 — Backend NASM mutável

`scripts/core/rune_nasm_mutable.gd`. Usado quando há `INT_SET` ou `INT_MOD`: as intensidades podem mudar em runtime, então **nem a altura da pilha nem os destinos dos portais** são conhecidos antes.

## O que precisa viver em memória no `.exe`

| Registrador | Guarda |
|---|---|
| `r12` | profundidade atual da pilha |
| `r13` | endereço da tabela de intensidades (1 byte por instrução) |
| `r14` | endereço da pilha (256 × qword) |
| `r15` | índice do `INT_SET` pendente (ou −1) |

Mais: os 256 slots de memória, um contador de passos (limite 10.000) e uma **tabela de endereços** dos blocos de instrução para saltos dinâmicos.

## Como uma instrução vira código

Cada instrução da IR vira um **bloco rotulado** (`instr_17:`). O bloco:
1. incrementa e testa o contador de passos;
2. lê sua intensidade atual de `[r13 + 17]` (não um imediato — pode ter mudado);
3. executa a operação nativa (push, add, compare…), checando pilha cheia/vazia;
4. se for portal, chama o **resolvedor de portais** (`_emit_portal_resolver`), que varre a tabela de intensidades em runtime seguindo as mesmas regras de [[07 Portais e Saltos]], e faz `jmp [tabela + destino*8]`.

`INT_SET` grava `r15`; a próxima produtora (checada por bloco) consome o topo, grava `[r13 + alvo]` e salta. `INT_MOD` lê a intensidade da operação seguinte, aplica em `[r13 + alvo]` com clamp 0–255 (`_emit_clamp`) e salta para o alvo.

> [!info] Continua não sendo um interpretador
> Não há loop `while (pc) switch (opcode)`. Cada runa já é código de máquina específico; a tabela só permite **saltar para um bloco cujo índice depende de um portal mutável**. O preço é um `.asm` bem maior que o estático.

## `rune_nasm_common.gd`

Compartilhado pelos dois backends:
- `emit_binary(lines, opcode, left, right, index)` — `add/sub/imul/idiv/cmp+setcc` para operações e comparações, com checagem de divisão por zero e de booleanos.
- `MAX_STACK_DEPTH = 256`, `MAX_RUN_STEPS = 10000`.
- `RUNTIME_ERRORS` — mensagens e rótulos de saída com código 1.

## Validação

`tests/nasm_all_runes.gd` (com `-Native`) compila cada runa, cada portal, cada mutação e os casos de erro, monta com NASM, liga com GCC, executa e **compara a saída com a VM**. Última rodada registrada: 56 executáveis + o `fibby.atelier` do usuário. Ver [[12 Testes e Ferramentas]].
