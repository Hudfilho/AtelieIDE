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
| Losango | `ADD` | Soma os dois valores no topo da pilha. |
| Lua | `SUB` | Subtrai o segundo valor do primeiro. |
| Sinal de + | `MUL` | Multiplica os dois valores do topo. |
| Triângulo | `PRINT` | Mostra o valor no Oráculo. |
| Cruz (X) | `HALT` | Encerra a execução. |
| Quadrado | `STORE` | Guarda o topo da pilha em uma posição de memória. |
| Forquilha | `LOAD` | Lê uma posição de memória para a pilha. |

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

O formato binário começa com a assinatura `RUNE`, seguida por uma versão, quantidade de instruções e os opcodes. Instruções que recebem operando — como `PUSH`, `STORE` e `LOAD` — carregam mais um byte com o valor de `0` a `255`.

## Próximos passos

- Ramificações e controle de fluxo visual.
- Salvar e abrir rituais pelo editor.
- Exportação de arquivos `.rune` pela interface.
- Depurador passo a passo com destaque da célula atual.
- Mais selos e ferramentas de linguagem.

---

Feito como projeto acadêmico de Compiladores, usando Godot e GDScript.
