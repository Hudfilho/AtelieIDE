---
tags: [semantica, controle-de-fluxo]
---
# 07 — Portais e saltos

`scripts/core/rune_portals.gd` é a **regra única** de destinos, usada pela VM e pela análise estática do NASM. Ele só calcula mapas; não executa nem valida.

## As três runas

- `WARP n` — salto incondicional pelo id `n` (a intensidade).
- `WARP END n` — marcador de destino. **Não é HALT**; a execução passa por ele.
- `JUMP_IF_TRUE n` — se topo `== 1`, salta como um `WARP n`; senão segue.

## Resolução (`RunePortals.resolve(instructions)`)

```
para cada id n:
  se existe exatamente 1 WARP END n:
      todo WARP n  → (índice do WARP END n) + 1
      todo JUMP n  → (índice do WARP END n) + 1
  senão, se há ≥ 2 WARP n:
      WARP n[i] → WARP n[(i+1) % k] + 1       ← anel na ordem das instruções
      JUMP n    → próximo WARP n depois dele (+1), ou o primeiro
```

> [!warning] O salto cai **depois** do marcador
> O destino é sempre `índice + 1`. Isso evita executar imediatamente outro `WARP` ao chegar num anel, e faz `WARP END` ser transparente.

## Erros

| Situação | Onde é detectada |
|---|---|
| Mais de um `WARP END n` | Compilador (`COMPILER_WARP_END_DUPLICATE`) e VM (`VM_WARP_MANY_ENDS`) |
| `WARP n` sem destino (nem END, nem outro WARP) | Compilador (`COMPILER_WARP_NO_TARGET`) e VM |
| `JUMP_IF_TRUE n` sem destino | Idem, com códigos `*_JUMP_*` |

O compilador **relaxa** essas checagens quando o programa é mutável (há `INT_SET`/`INT_MOD` que podem alterar um portal): o id só é conhecido em runtime, então a VM e o backend mutável fazem a verificação na hora.

## Portais atravessam sequências

Os portais são procurados em **todas** as sequências. É assim que uma segunda sequência (que nunca executa sozinha, ver [[03 Frontend — Linearização e Validação]]) vira uma "sub-rotina": `WARP 7` na primeira, `WARP END 7` no começo da segunda.

## Exemplo — laço de contagem

```
PUSH 3 → WARP END 1 → PRINT → PUSH 1 → SUB → DUP → PUSH 0 → GT → JUMP_IF_TRUE 1 → HALT
```
Imprime `321`. O `JUMP_IF_TRUE 1` volta para logo após o `WARP END 1` enquanto o topo for 1.
