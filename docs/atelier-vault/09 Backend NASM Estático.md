---
tags: [backend, nasm]
---
# 09 — Backend NASM estático

`scripts/core/rune_nasm_exporter.gd` (`AtelierRuneNasmExporter`). Escolhido automaticamente quando o programa **não** contém `INT_SET`/`INT_MOD`. Gera código nativo Windows x86-64 em sintaxe NASM.

## Ideia central

Intensidades fixas ⇒ destinos de portais conhecidos em tempo de compilação ⇒ dá para resolver os saltos **antes** de gerar código e dar a cada posição da pilha um **endereço fixo** no frame de `main`.

## Pipeline

1. `RuneCompiler.compile()` → IR.
2. `RunePortals.resolve()` → mapas de salto (os mesmos da VM, ver [[07 Portais e Saltos]]).
3. `_analyze_program` — percorre o grafo de fluxo a partir da entrada calculando a **altura da pilha** em cada instrução alcançável (`required_stack_depth` + `stack_delta` do catálogo).
   - Falta de valores → erro antes de exportar.
   - Dois caminhos chegando à mesma instrução com alturas diferentes → erro (não há *phi*).
   - `JUMP_IF_TRUE` é analisado pelos dois ramos, sem prever o booleano.
   - Instruções inalcançáveis **não são emitidas**.
4. `_build_source` — emite o texto. Cada posição `k` da pilha é `[rsp + 32 + 8k]`. Saltos viram `jmp`/`je` para rótulos.

## Exemplo real — `PUSH 128 → PRINT`

```nasm
default rel
extern printf
global main
section .data
format_integer: db "%lld", 0
section .text
main:
    sub rsp, 40
    mov qword [rsp + 32], 128      ; PUSH
    mov rdx, [rsp + 32]            ; PRINT
    lea rcx, [rel format_integer]
    call printf
    add rsp, 40
    xor eax, eax
    ret
```

> [!info] Não existe "uma função por runa"
> `PUSH` virou um `mov`; `PRINT` virou uma chamada a `printf`. As funções GDScript (`_emit_instruction` etc.) organizam o **gerador de texto**; nada delas existe no `.exe`.

## Convenção Windows x64

Shadow space de 32 bytes, pilha alinhada a 16 antes de `call`, argumentos em `rcx`/`rdx`. Saída numérica usa `%lld` (64 bits com sinal). `PRINTLETTER` emite UTF-8 para 0–255.

## Erros em runtime (mesmo no estático)

Divisão por zero, `NOT`/`AND`/`OR` com não-booleano, slot de memória vazio: o código gerado testa e, em caso de erro, imprime a mensagem de `RUNTIME_ERRORS` e termina com código `1`. Sucesso retorna `0`.

O código binário compartilhado (`ADD`, comparações…) vive em `rune_nasm_common.gd` — ver [[10 Backend NASM Mutável]].
