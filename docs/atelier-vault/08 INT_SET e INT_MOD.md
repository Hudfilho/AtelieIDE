---
tags: [semantica, metaprogramacao]
---
# 08 — `INT_SET` e `INT_MOD`: o programa que se reescreve

Essas duas runas são a parte mais original da linguagem: alteram a **intensidade de outras instruções durante a execução**. Elas operam na cópia `state["program"]`, nunca no desenho salvo.

## INT_SET — "a próxima produtora decide o valor"

1. Ao executar, arma `pending_int_set = índice`. Dois `INT_SET` pendentes = erro.
2. A próxima instrução executada com **índice maior** e `result_type: "int"` no catálogo é a *produtora*. Seu resultado é **removido** da pilha, limitado a 0–255, e aplicado à intensidade da instrução **seguinte à produtora** (o *alvo*).
3. A execução pula direto para o alvo já alterado.

```
INT_SET → PUSH 42 → PUSH 0 → PRINT        saída: 42
          produtora  alvo
```

Erros: terminar sem produtora (`VM_INT_SET_NO_VALUE`), alvo inexistente ou `HALT` (`VM_INT_SET_NO_TARGET`).

> [!warning] Produtora é quem declara `result_type: "int"`
> O critério é o catálogo, não a proximidade visual. Um salto pode levar até uma produtora em outra sequência. Uma runa nova que **não** deixa inteiro na pilha numérica não pode ter `result_type: "int"`, senão `INT_SET` consome lixo. Isso é crítico para [[14 Runas Mágicas — Mudanças para o Jogo]].

## INT_MOD — "a operação seguinte modifica o alvo seguinte"

```
INT_MOD → ADD (int. 10) → PUSH 20 → PRINT     vira PUSH 30, saída: 30
          operação        alvo
```

- A operação precisa estar em `INTENSITY_OPERATIONS` (`ADD SUB MUL DIV MOD NEG`) e **não executa na pilha** — é consumida como modificador.
- `alvo.intensidade = alvo.intensidade (op) operação.intensidade`, limitado a 0–255. `NEG` ignora a intensidade da operação.
- `DIV`/`MOD` por zero é erro. O fluxo pula a operação e continua no alvo.

## O que pode ser alvo

Qualquer instrução. Mudar a intensidade de:
- `PUSH` → muda o número;
- `STORE`/`LOAD`/`READ` → muda o endereço;
- `WARP`/`WARP END`/`JUMP_IF_TRUE` → muda o portal (por isso a VM refaz `configure_program`);
- `PRINTLETTER` → muda a letra.

## Validação estática (compilador)

`_validate_rune_dependencies` exige que operação e alvo de `INT_MOD` estejam na **mesma sequência** (`_same_sequence_rune`), e que `INT_SET` tenha uma produtora e um alvo adiante — a menos que haja `WARP`/`JUMP_IF_TRUE` entre eles (o valor pode vir de outra sequência). `_potential_intensity_targets` marca instruções que podem mudar, e as checagens de portal são relaxadas para elas.

## Por que isso importa para o jogo

É o mecanismo que permite "obter propriedades fortes a partir de poucos recursos": uma runa mágica com intensidade baixa pode ser amplificada por `INT_MOD MUL` antes de executar. A função `_set_instruction_intensity` é genérica, então runas novas já são alvos válidos sem código extra.
