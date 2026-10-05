# Como funciona o compilador do Atelier IDE

O Atelier é uma linguagem visual baseada em pilha. O desenho das runas é o código-fonte; o compilador organiza esse desenho em instruções e pode gerar bytecode para a VM do editor ou assembly NASM para Windows x86-64. O assembly gerado não depende do Godot para executar.

## 1. O caminho completo

```text
Diagrama na tela / arquivo .atelier
                |
      Ordenação e validação
                |
      Lista de instruções (IR)
          /             \
  Bytecode RUNE       Assembly .asm
       |                  |
  VM do editor       NASM -> .obj
                          |
                     GCC -> .exe
```

| Representação | O que contém |
| --- | --- |
| `.atelier` | JSON editável: pontos, conexões, símbolos e intensidades. |
| IR | Lista de dicionários em memória, com opcode, intensidade e origem no desenho. |
| `.rune` | Bytecode binário compacto, executável pela VM do Atelier. |
| `.asm` | Texto NASM com instruções reais da CPU e chamadas de saída. |
| `.obj` | Código de máquina montado pelo NASM, ainda com referências externas a resolver. |
| `.exe` | Programa ligado pelo GCC com o suporte necessário da biblioteca C. |

Exportar o aplicativo pelo Godot e exportar um ritual para NASM são coisas diferentes: o primeiro distribui a IDE; o segundo compila o programa desenhado nela.

## 2. Como o desenho vira instruções

O frontend está em [`rune_compiler.gd`](../scripts/core/rune_compiler.gd). Ele recebe as conexões do diagrama e:

1. Agrupa conexões que compartilham pontos, formando sequências.
2. Rejeita bifurcações geométricas: um ponto não pode ter mais de duas conexões.
3. Exige duas pontas por sequência. Um círculo fechado no desenho não define uma ordem de execução válida.
4. Escolhe o início pela ponta com menor `x`; em empate, menor `y`. Ordena as sequências pelo mesmo critério.
5. Percorre cada sequência, ignora células sem selo e consulta o catálogo para converter o `kind` do símbolo em opcode.
6. Acrescenta um `HALT` implícito ao final de cada sequência com instruções, se ela não terminar com um `HALT` explícito.
7. Valida dependências das runas e gera as instruções e o bytecode.

A primeira sequência com instruções é a entrada do programa. As demais não executam automaticamente depois dela: são acessíveis por saltos. Loops continuam possíveis por `WARP` e `JUMP_IF_TRUE`, sem precisar desenhar um círculo fechado.

Uma instrução da IR pode ter esta forma:

```gdscript
{
    "opcode": 1,            # PUSH
    "intensity": 128,
    "operand": 128,
    "connection_index": 0, # célula de origem
    "sequence_index": 0
}
```

O `connection_index` permite destacar no canvas a célula executada ou com erro. Não é endereço de máquina nem parte do bytecode.

### Onde entram as análises da disciplina?

| Etapa | Implementação no Atelier |
| --- | --- |
| Identificação dos símbolos, equivalente visual à análise léxica | O catálogo associa cada `kind` a um opcode, nome e propriedades. |
| Análise estrutural/sintática | Verifica o grafo, suas pontas e a ordem das células. |
| Análise semântica | Verifica dependências como destinos de portais e requisitos de `INT_SET`/`INT_MOD`. Parte dos erros só pode ser verificada durante a execução. |
| Geração de código | Produz bytecode RUNE ou assembly NASM. |

Não existe um lexer de texto, parser textual ou AST tradicional neste protótipo. Os selos já chegam identificados pela interface; **o compilador não reconhece as imagens por pixels**.

## 3. Pilha, memória e intensidade

A pilha guarda os valores usados nas contas. Por exemplo:

```text
Início:   []
PUSH 2:   [2]
PUSH 3:   [2, 3]
ADD:      [5]
PRINT:    [5]        saída: 5
```

`PRINT` consulta o topo sem removê-lo e não acrescenta espaço ou quebra de linha. `STORE`, por outro lado, remove o topo para guardá-lo na memória. `LOAD` e `READ` empilham o conteúdo de um endereço já inicializado; `READ` não solicita entrada pelo teclado.

A intensidade dos selos vai de `0` a `255`. Dependendo da runa, ela é um número, endereço, identificador de portal ou caractere. Isso não limita os resultados das contas a 255: a VM usa inteiros de 64 bits, e o NASM usa operações inteiras de 64 bits com sinal.

Comparações produzem `0` ou `1`. `NOT`, `AND` e `OR` rejeitam outros valores. `JUMP_IF_TRUE` testa se o topo é exatamente `1` e não o remove.

As propriedades compartilhadas ficam em [`rune_catalog.gd`](../scripts/core/rune_catalog.gd): opcode, uso de operando, tipo produzido, quantidade mínima de valores e variação da altura da pilha. Assim o exportador não precisa manter outra tabela dessas regras.

## 4. Bytecode RUNE e VM

[`rune_bytecode.gd`](../scripts/core/rune_bytecode.gd) define o formato RUNE, versão 2:

- Cabeçalho de 7 bytes: assinatura `RUNE`, versão e quantidade de instruções em um inteiro de 16 bits, little-endian.
- Cada instrução ocupa 2 bytes: `[opcode][intensidade]`.
- O limite do formato é 65.535 instruções. O compilador rejeita programas maiores, sem truncá-los silenciosamente.
- O decoder rejeita assinatura, versão ou opcode inválidos, instruções incompletas e bytes extras depois do programa.

Um exemplo de `PUSH 128`, `PRINT` com intensidade zero e `HALT` implícito ocupa apenas 13 bytes:

```text
52 55 4E 45 02 03 00 01 80 05 00 06 00
```

Os primeiros quatro bytes são `RUNE`; `02` é a versão; `03 00` informa três instruções. Os três pares restantes são `PUSH 128`, `PRINT` e `HALT`.

[`rune_vm.gd`](../scripts/core/rune_vm.gd) mantém pilha, memória, saída, erros e estado das intensidades mutáveis. A execução acompanha um contador de instrução: ele fica no loop de `run` ou na interface, quando a execução é incremental. A cada `step`, a VM recebe a instrução e seu índice, executa a operação e informa o salto, se houver.

No Play, a interface compila, decodifica o bytecode e recoloca os índices das células no programa decodificado. Depois chama `step` na velocidade configurada em RPS, atualizando pilha, Oráculo e destaque visual. Erros com origem identificada marcam a célula; erros gerais de estrutura podem não ter uma célula única para destacar.

`VM.run`, usado pelas ferramentas e testes, tem um limite de 10.000 passos. O Play usa execução incremental e atualmente não aplica esse mesmo limite global.

## 5. Portais e saltos

[`rune_portals.gd`](../scripts/core/rune_portals.gd) centraliza a resolução dos destinos usada pela VM e pela análise do exportador estático. Os portais são procurados em todas as sequências.

- `WARP n`: se existe um único `WARP END n`, ele é o destino prioritário. Sem ele, dois ou mais `WARP n` formam um anel na ordem das instruções: cada um salta para o próximo, e o último volta ao primeiro.
- `WARP END n`: é um marcador de destino. Não é um `HALT`.
- `JUMP_IF_TRUE n`: se o topo é `1`, procura primeiro o `WARP END n`; sem ele, procura o próximo `WARP n` depois da instrução, voltando ao primeiro quando necessário. Com outro valor no topo, segue normalmente.
- O salto continua **depois** do marcador de destino, evitando executar imediatamente outro salto.

Destinos ausentes e mais de um `WARP END` com o mesmo identificador são erros. Quando uma intensidade muda durante a execução, a VM refaz os mapas; o backend NASM mutável faz a busca em tempo de execução.

## 6. As duas runas que mudam o programa

### INT_SET

`INT_SET` arma uma alteração pendente. A próxima instrução executada que declare resultado inteiro no catálogo, e cujo índice seja maior que o do setter, fornece o valor. Esse valor é removido da pilha, limitado a `0..255` e aplicado à intensidade da instrução seguinte à produtora.

```text
INT_SET -> PUSH 42 -> PUSH 0 -> PRINT
```

Nesse exemplo, o primeiro `PUSH` fornece `42` para alterar o segundo `PUSH`. O segundo passa a empilhar `42`, e `PRINT` mostra `42`.

O critério não é apenas proximidade visual: saltos podem levar até uma produtora em outra sequência. Porém, o índice maior é uma regra atual da VM que o NASM também respeita. Uma nova runa numérica só pode alimentar o setter se declarar `result_type: "int"` e produzir seu valor no topo da pilha.

Há erro se outro setter for ativado enquanto um está pendente, se a execução terminar sem fornecer o valor ou se a produtora não tiver um alvo válido seguinte, diferente de `HALT`.

### INT_MOD

`INT_MOD` usa a próxima instrução como operação e a seguinte como alvo. As operações permitidas são `ADD`, `SUB`, `MUL`, `DIV`, `MOD` e `NEG`.

```text
INT_MOD -> ADD (intensidade 10) -> PUSH 20 -> PRINT
```

O resultado é um `PUSH 30`: soma a intensidade da operação à intensidade do alvo. A runa `ADD` é consumida como modificador, não executa uma soma na pilha. O fluxo pula essa operação e continua no alvo alterado.

O resultado é limitado a `0..255`. `NEG` ignora a intensidade da operação, inverte o sinal do alvo e depois aplica esse limite. Divisão ou resto por zero continuam sendo erros.

O alvo não precisa ser `PUSH`: mudar intensidade também pode alterar endereço de memória, portal ou letra. Essas alterações pertencem à cópia do programa em execução, **não reescrevem o ritual salvo**.

## 7. Como o NASM é gerado

[`rune_nasm_exporter.gd`](../scripts/core/rune_nasm_exporter.gd) escolhe automaticamente um de dois caminhos. Ambos suportam as 30 runas do catálogo atual.

### Caminho estático: sem INT_SET ou INT_MOD

Como as intensidades são fixas, o exportador resolve os saltos antes de gerar o código. Percorre o grafo de fluxo a partir da entrada e calcula a altura da pilha em cada instrução alcançável.

Essa análise detecta falta de valores e exige que os caminhos que chegam à mesma instrução tenham a mesma altura de pilha. Analisa os dois caminhos do salto condicional, sem tentar prever o valor do booleano. Instruções não alcançáveis não são emitidas.

Cada posição da pilha recebe um endereço fixo no frame de `main`, como `[rsp + 32]`. A memória só reserva os endereços usados. Saltos viram `jmp` ou `je` para rótulos nativos.

Um exemplo simplificado e funcional de `PUSH 128 -> PRINT` fica assim:

```nasm
default rel
extern printf
global main

section .data
format_integer: db "%lld", 0

section .text
main:
    sub rsp, 40
    mov qword [rsp + 32], 128
    mov rdx, [rsp + 32]
    lea rcx, [rel format_integer]
    call printf
    add rsp, 40
    xor eax, eax
    ret
```

Não existe uma função por runa: `PUSH` virou um `mov`, e `PRINT` virou uma chamada a `printf`. As funções em GDScript são organizadoras do **gerador de texto**, não métodos que precisam executar no programa exportado. Rótulos de salto também não são funções.

### Caminho mutável: com INT_SET ou INT_MOD

[`rune_nasm_mutable.gd`](../scripts/core/rune_nasm_mutable.gd) precisa manter em memória as intensidades, a pilha, os 256 endereços de memória e o setter pendente. Usa blocos nativos para as instruções e uma tabela de endereços para saltos dinâmicos.

Os registradores preservados `r12`, `r13`, `r14` e `r15` guardam, respectivamente, profundidade da pilha, endereço das intensidades, endereço da pilha e setter pendente. Os destinos dos portais são consultados com os valores atuais.

Não é um loop interpretando bytecodes: as operações de cada runa já foram traduzidas para instruções da CPU. O código extra mantém o estado mutável e verifica erros em tempo de execução. Por isso esse caminho gera assembly maior.

Os dois caminhos compartilham [`rune_nasm_common.gd`](../scripts/core/rune_nasm_common.gd) para emitir operações binárias. Respeitam a convenção de chamadas Windows x64, incluindo alinhamento da pilha e os 32 bytes de shadow space para chamar `printf`.

`PRINTLETTER` emite UTF-8 para intensidades de `0..255`; zero produz o caractere de substituição `U+FFFD`, mantendo o comportamento atual de `String.chr(0)` na VM. Saída numérica usa inteiro de 64 bits com sinal. Erros nativos imprimem uma mensagem e terminam com código `1`; sucesso retorna `0`.

## 8. Como exportar, executar e testar

No menu **File → Exportar Assembly NASM**, escolha o `.asm`. O menu gera somente o assembly; montar e ligar são etapas externas.

Para montar, ligar e executar no Windows:

```powershell
powershell -ExecutionPolicy Bypass -File C:\godot\atelier-ide\tools\run_exported_asm.ps1 C:\caminho\ritual.asm
```

A ferramenta procura NASM/GCC UCRT64 no MSYS2 em `D:\msys64` ou `C:\msys64`, ou na pasta indicada por `ATELIER_MSYS2_ROOT`. Executa `nasm -f win64` e depois GCC. Cria `.obj` e `.exe` ao lado do `.asm`; arquivos anteriores com esses mesmos nomes podem ser substituídos.

Os testes básicos precisam só do Godot. Acrescentar `-Native` exige NASM/GCC e compara executáveis reais com a VM:

```powershell
$godotConsole = 'C:\Users\Pichau\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File C:\godot\atelier-ide\tools\run_tests.ps1 -GodotPath $godotConsole
powershell -ExecutionPolicy Bypass -File C:\godot\atelier-ide\tools\run_tests.ps1 -GodotPath $godotConsole -Native -RitualPath C:\Users\Pichau\Downloads\fibby.atelier
```

O runner cobre contratos do catálogo/bytecode, diagnósticos, menu de arquivos, geometria dos painéis, edição dos nós e geração NASM. Detecta `SCRIPT ERROR` e assertions mesmo quando um teste antigo retorna código zero. A suíte nativa cobre todas as runas, portais, mutações, saída UTF-8 e erros, com captura de bytes e timeout por executável. Na validação desta revisão, passaram 8 suítes e 56 comparações nativas, incluindo o Fibonacci fornecido pelo usuário.

## 9. Limitações atuais

- O assembly tem um único alvo: Windows x86-64, sintaxe NASM. Linux e ARM exigiriam outro backend.
- O backend estático rejeita convergências com alturas de pilha diferentes. Ainda não há análise de valores constantes ou alocação avançada de registradores.
- A pilha nativa tem limite de 256 valores. O backend mutável também limita a execução a 10.000 passos; o estático não tem contador global de passos.
- Dependências que mudam por `INT_SET`/`INT_MOD` nem sempre podem ser comprovadas antecipadamente; continuam existindo validações de runtime.
- Os testes cobrem as operações atuais, mas não constituem prova de equivalência para todos os casos de overflow extremo de inteiros.
- A API exporta bytecode `.rune`, mas o menu atual oferece salvar/abrir `.atelier` e exportar `.asm`.
- A configuração local do projeto referencia traduções ausentes em `localization/`. Isso gera avisos do Godot; essa configuração preexistente foi preservada na revisão.

## Resumo para explicar o projeto

“O Atelier usa um frontend visual que ordena e valida um grafo de runas, gerando uma representação intermediária. A partir dela, emite bytecode para uma máquina virtual de pilha ou assembly x86-64 nativo. Portais viram saltos; alterações de intensidade usam um backend com estado mutável e verificações em tempo de execução.”
