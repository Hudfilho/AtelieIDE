# Atelier IDE

> Uma IDE visual para uma linguagem de runas inspirada em *Witch Hat Atelier*.

**Atelier IDE** é um protótipo de projeto para a disciplina de Compiladores. Em vez de escrever instruções em texto, o programa é desenhado numa grade: cada ligação é uma célula de execução e os selos colocados sobre ela formam o ritual.

O resultado é compilado para um bytecode próprio (`RUNE`) e executado por uma máquina virtual simples.

## Ideia

Cada sequência de linhas representa o fluxo do programa. Os selos são instruções de uma linguagem baseada em pilha:

```text
PUSH 2 → PUSH 2 → ADD → PRINT → HALT
```

No canvas, a intensidade de um selo vai de `0` a `255`. Para instruções como `PUSH`, ela também é o valor numérico usado no programa.

## Recursos atuais

- Grade infinita com pan e zoom.
- Criação encadeada de ligações entre pontos.
- Encaixe magnético ao aproximar uma linha de uma âncora.
- Paleta de selos arrastável.
- Intensidade configurável por slider ou valor numérico.
- Seleção individual e múltipla de células.
- Seleção retangular e remoção com histórico (`Ctrl+Z` / `Ctrl+Y`).
- Painéis redimensionáveis para grimório, selos e saída.
- Compilador visual → bytecode `RUNE` → máquina virtual.
- Oráculo de execução com saída, avisos e erros.

## Controles

| Ação | Controle |
| --- | --- |
| Criar uma ligação | Arraste de um ponto vermelho até outro ponto |
| Continuar uma sequência | Mantenha o botão esquerdo pressionado ao alcançar uma âncora |
| Navegar pelo canvas | Arraste com o botão do meio |
| Zoom | Roda do mouse sobre o canvas |
| Colocar ou mover um selo | Arraste um selo da paleta para uma linha |
| Configurar intensidade | Clique em um selo e use o slider ou o campo numérico |
| Selecionar uma célula | Clique na linha |
| Adicionar/remover da seleção | `Ctrl` + clique numa linha |
| Seleção múltipla | Arraste numa área vazia do canvas |
| Apagar células | `Delete` ou `Backspace` |
| Desfazer / refazer | `Ctrl+Z` / `Ctrl+Y` |
| Rolar o grimório | Roda do mouse ou arraste a lista para cima/baixo |
| Executar o ritual | Botão ▶ no canto superior direito |

## Selos disponíveis

| Selo | Instrução | Efeito |
| --- | --- | --- |
| Orbe | `PUSH` | Coloca a intensidade do selo na pilha. |
| Cálice | `DROP` | Descarta o valor no topo da pilha. |
| Gêmeos | `DUP` | Duplica o valor no topo da pilha. |
| Nó | `SWAP` | Troca os dois valores no topo da pilha. |
| Losango | `ADD` | Soma os dois valores no topo da pilha. |
| Lua | `SUB` | Subtrai o topo do penúltimo valor. |
| Sinal de + | `MUL` | Multiplica os dois valores no topo da pilha. |
| Barra | `DIV` | Divide o penúltimo valor pelo valor do topo, com resultado inteiro. |
| Espiral | `MOD` | Calcula o resto da divisão entre os dois valores do topo. |
| Traço | `NEG` | Inverte o sinal do valor no topo da pilha. |
| Espelho duplo | `EQ` | Coloca `1` se os dois valores forem iguais; caso contrário, `0`. |
| Espelho cortado | `NEQ` | Coloca `1` se os dois valores forem diferentes; caso contrário, `0`. |
| Vira à esquerda | `LT` | Coloca `1` se o penúltimo valor for menor que o topo. |
| Vira à direita | `GT` | Coloca `1` se o penúltimo valor for maior que o topo. |
| Vira à esquerda com base | `LTE` | Coloca `1` se o penúltimo valor for menor ou igual ao topo. |
| Vira à direita com base | `GTE` | Coloca `1` se o penúltimo valor for maior ou igual ao topo. |
| Círculo cortado | `NOT` | Inverte um booleano: `1` vira `0`; `0` vira `1`. |
| Arco unido | `AND` | Coloca `1` somente quando os dois booleanos forem `1`. |
| Arco aberto | `OR` | Coloca `1` quando pelo menos um dos booleanos for `1`. |
| Portal | `WARP` | Salta para outro `WARP` com a mesma intensidade. |
| Portal selado | `WARP END` | Destino compartilhado por todos os `WARP` com a mesma intensidade. |
| Seta de decisão | `JUMP_IF_TRUE` | Se o topo da pilha for `001`, salta para o `WARP` ou `WARP END` com a mesma intensidade. |
| Círculo modificado | `INT_MOD` | Aplica uma operação à intensidade do selo-alvo. |
| Quadrado modificado | `INT_SET` | Aguarda qualquer runa que produza um inteiro e o aplica ao selo-alvo. |
| Triângulo | `PRINT` | Mostra o valor no Oráculo. |
| Letra rúnica | `PRINTLETTER` | Mostra o caractere Unicode indicado pela intensidade: `032` é espaço e `010` é quebra de linha. |
| Cruz (X) | `HALT` | Encerra a execução. |
| Quadrado | `STORE` | Guarda o topo da pilha em uma posição de memória. |
| Forquilha | `LOAD` | Lê uma posição de memória para a pilha. |
| Seta para o olho | `READ` | Usa o topo da pilha como endereço, empilha o valor da memória e preserva o endereço. |

Para uma runa nova poder alimentar um `INT_SET`, ela deve produzir seu valor no topo da pilha e declarar `"result_type": "int"` no catálogo. Assim o `INT_SET` não precisa ser alterado a cada selo numérico novo.

Os booleanos da linguagem usam `1` para verdadeiro e `0` para falso. `EQ`, `NEQ`, `LT`, `GT`, `LTE` e `GTE` sempre devolvem um desses dois valores; `NOT`, `AND` e `OR` aceitam somente `0` ou `1`.

## Como executar

1. Instale o [Godot Engine 4.7](https://godotengine.org/download/).
2. Clone o repositório:

   ```bash
   git clone https://github.com/Hudfilho/AtelieIDE.git
   ```

3. Abra a pasta clonada no Godot.
4. Aperte `F6` ou use **Run Project**.

## Estrutura

```text
scenes/
└── Main.tscn                 # Cena principal

scripts/
├── atelier_canvas.gd         # Canvas, interação e interface
└── core/
    ├── rune_catalog.gd       # Catálogo de selos e opcodes
    ├── rune_diagram.gd       # Estado do diagrama e histórico
    ├── rune_compiler.gd      # Diagrama → instruções → bytecode
    ├── rune_bytecode.gd      # Formato binário RUNE
    └── rune_vm.gd            # Máquina virtual baseada em pilha
```

## Bytecode `RUNE`

O formato binário começa com a assinatura `RUNE`, seguida por uma versão, quantidade de instruções e os opcodes. Cada instrução carrega sua intensidade de `0` a `255`; em instruções como `PUSH`, `STORE`, `LOAD`, `WARP` e `PRINTLETTER`, essa intensidade também é o operando numérico.

Cada instrução ocupa dois bytes: `[opcode][intensidade]`. Por exemplo, `PUSH 006` é `01 06` em hexadecimal, ou `00000001 00000110` em binário. Selos que não usam operando ainda carregam o segundo byte como intensidade visual.

| Instrução | Opcode (hex) | Opcode (binário) |
| --- | --- | --- |
| `PUSH` | `01` | `00000001` |
| `ADD` | `02` | `00000010` |
| `SUB` | `03` | `00000011` |
| `MUL` | `04` | `00000100` |
| `PRINT` | `05` | `00000101` |
| `HALT` | `06` | `00000110` |
| `STORE` | `07` | `00000111` |
| `LOAD` | `08` | `00001000` |
| `DROP` | `09` | `00001001` |
| `DUP` | `0A` | `00001010` |
| `SWAP` | `0B` | `00001011` |
| `DIV` | `0C` | `00001100` |
| `MOD` | `0D` | `00001101` |
| `NEG` | `0E` | `00001110` |
| `WARP` | `0F` | `00001111` |
| `INT_MOD` | `10` | `00010000` |
| `INT_SET` | `11` | `00010001` |
| `EQ` | `12` | `00010010` |
| `NEQ` | `13` | `00010011` |
| `LT` | `14` | `00010100` |
| `GT` | `15` | `00010101` |
| `LTE` | `16` | `00010110` |
| `GTE` | `17` | `00010111` |
| `NOT` | `18` | `00011000` |
| `AND` | `19` | `00011001` |
| `OR` | `1A` | `00011010` |
| `WARP END` | `1B` | `00011011` |
| `PRINTLETTER` | `1C` | `00011100` |
| `JUMP_IF_TRUE` | `1D` | `00011101` |
| `READ` | `1E` | `00011110` |

## Próximos passos

- Ramificações e controle de fluxo visual.
- Salvar e abrir rituais pelo editor.
- Exportação de arquivos `.rune` pela interface.
- Depurador passo a passo com destaque da célula atual.
- Mais selos e ferramentas de linguagem.

---

Feito como projeto acadêmico de Compiladores, usando Godot e GDScript.
