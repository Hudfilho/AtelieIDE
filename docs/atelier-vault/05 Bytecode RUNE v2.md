---
tags: [backend, bytecode]
---
# 05 — Bytecode RUNE v2

`scripts/core/rune_bytecode.gd` (`AtelierRuneBytecode`).

## Layout

```
offset  bytes  conteúdo
0       4      "RUNE"  (52 55 4E 45)
4       1      versão = 2
5       2      quantidade de instruções, uint16 little-endian
7..     2×N    [opcode][intensidade]  por instrução
```

Exemplo — `PUSH 128`, `PRINT`, `HALT` implícito (13 bytes):

```
52 55 4E 45 | 02 | 03 00 | 01 80 | 05 00 | 06 00
  "RUNE"     ver   N=3    PUSH128  PRINT   HALT
```

## Regras do encoder

- Mais de 65.535 instruções → devolve `PackedByteArray()` vazio (o compilador já rejeitou antes).
- Intensidade sempre `clampi(0, 255)`.

## Regras do decoder

Rejeita, com erro: tamanho menor que o cabeçalho, assinatura errada, versão ≠ 2, opcode desconhecido, instrução truncada e **bytes sobrando** depois das N instruções declaradas. Não há tolerância a lixo.

Na decodificação, `operand` é recriado a partir da intensidade quando `takes_operand(opcode)`.

> [!info] Por que 1 byte de intensidade não limita as contas
> A intensidade é só o literal/operando. A pilha da VM usa `int` de 64 bits; o NASM usa `qword` com sinal. `PUSH 200, PUSH 200, MUL` dá 40.000 sem problema.

## Espaço para crescer

Opcodes vão até `0x1e`; sobram `0x1f`–`0xff`. Uma runa nova **não** exige versão 3 do formato, desde que mantenha o par `[opcode][intensidade]`. Se um dia uma instrução precisar de mais de 1 byte de operando, aí sim é versão nova.
