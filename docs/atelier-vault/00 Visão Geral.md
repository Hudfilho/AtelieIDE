---
tags: [compilador, visao-geral]
---
# 00 — Visão geral

O **Atelier** é uma linguagem visual baseada em pilha, inspirada em *Witch Hat Atelier*. O programa é um **desenho**: o usuário liga pontos de uma grade, e cada segmento (célula) pode receber uma **runa** e uma **intensidade de 0 a 255**.

O compilador transforma esse desenho em três coisas, nesta ordem:

```
Diagrama (.atelier)
      │
      ▼
Frontend: linearização + validação      ← [[03 Frontend — Linearização e Validação]]
      │
      ▼
IR: lista de instruções com origem      ← [[04 Representação Intermediária (IR)]]
      │
      ├──────────────► Bytecode RUNE v2 ──► VM do editor   ← [[05 Bytecode RUNE v2]], [[06 Máquina Virtual]]
      │
      └──────────────► Assembly NASM ─────► nasm → gcc → .exe   ← [[09 Backend NASM Estático]], [[10 Backend NASM Mutável]]
```

## Em uma frase

> O frontend ordena e valida um grafo de runas e produz uma IR; dela, o compilador emite bytecode para uma VM de pilha **ou** assembly x86-64 nativo. Portais viram saltos; alterações de intensidade exigem um backend com estado mutável e checagens em tempo de execução.

## O que o compilador NÃO faz

- Não lê pixels. Os símbolos chegam identificados pela interface (o `kind` da célula).
- Não tem lexer textual, parser nem AST clássica — a "sintaxe" é a **topologia do desenho**.
- Não executa NASM/GCC sozinho: a IDE exporta `.asm`; montar e ligar é externo (`tools/run_exported_asm.ps1`).

## Onde cada análise da disciplina aparece

| Etapa clássica | No Atelier |
|---|---|
| Léxica | [[02 Catálogo de Runas]]: `kind` → opcode e propriedades |
| Sintática | [[03 Frontend — Linearização e Validação]]: grafo, pontas, ordem |
| Semântica | Dependências de portais, `INT_SET`/`INT_MOD`; parte só verificável em runtime |
| Geração de código | [[05 Bytecode RUNE v2]] ou NASM |

## Números úteis

- 30 runas no catálogo (opcodes `0x01`–`0x1e`).
- Instrução = 2 bytes no bytecode; limite de 65.535 instruções.
- Pilha nativa: 256 valores. VM de testes e backend mutável: 10.000 passos.
- Inteiros de 64 bits com sinal nas contas; intensidade continua em 0–255.
