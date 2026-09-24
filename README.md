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
- Ateliê à luz de vela ou pergaminho iluminado, com o tema guardado entre sessões.
- Menu File para salvar e abrir rituais editáveis (`.atelier`).
- Verificação de erros no Play com marcação da célula problemática.

## Controles

| Ação | Controle |
| --- | --- |
| Criar uma ligação | Arraste de um ponto vermelho até outro ponto |
| Continuar uma sequência | Arraste de uma ponta livre, passando pelos pontos sem soltar o botão esquerdo |
| Apagar a última célula durante o traçado | Volte ao ponto imediatamente anterior sem soltar o botão |
| Alternar o modo de mover uma ponta | Dê duplo clique nela; a barrinha perpendicular indica o modo ativo |
| Mover uma junção | Arraste-a para um ponto livre |
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
| Alternar dia / noite | Botão ☾ / ☀ no canto superior direito |
| Salvar / abrir ritual | Menu File ou `Ctrl+S` / `Ctrl+O` |
| Diagnóstico de desempenho | `F3`; `F6` alterna o cache dos painéis e `F7` a camada visual |

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
| Seta para o olho | `READ` | Empilha o valor da memória no endereço indicado pela intensidade do selo. |

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

## Demo do jogo (branch `game-case`)

O projeto agora abre numa tela inicial com duas opções: **Open the shop**, o demo do jogo, e **Rune sandbox**, a IDE livre de sempre.

No demo você cuida de uma loja de pergaminhos, inspirada em *Papers, Please*, *Potion Craft* e *Witch Hat Atelier*:

1. Toque o sino para chamar o próximo cliente.
2. Inspecione: clique num campo do pedido e depois na regra do livro que ele viola, ou na ordem inversa. Ligações certas viram provas, marcadas em tinta vermelha; as erradas voltam como contradição. A primeira ligação errada com um cliente não custa nada. A partir da segunda ele se impacienta, e ao chegar ao limite (3, configurável em `inspection_mistake_threshold` no `Desk`) a loja perde 1 de reputação, uma única vez por cliente. Cada cliente novo começa do zero.
3. Carimbe **REJECT** ou **APPROVE**. Uma recusa só é correta se citar ao menos uma prova válida. Recusar sem prova conta como recusa sem motivo, mesmo que o pedido seja ilegal.
4. Se aprovar, escreva o pergaminho na bancada, que é o editor de runas em modo jogo, só com as runas liberadas no dia. **Deliver scroll** roda o ritual contra os casos de teste da encomenda.
5. No fim do dia aparece o livro-caixa. As decisões têm consequências, algumas na hora e outras nas manhãs seguintes: jornal, multas, reputação e flags do mundo, como `guild_suspicion`. As flags mudam quem aparece nos dias seguintes. No dia 3, por exemplo, o inspetor da Guilda faz uma visita de rotina ou uma auditoria, conforme a suspeita acumulada.

| Pasta | Conteúdo |
| --- | --- |
| `scenes/game/` | `Title`, `Desk` (balcão) e `Workbench` (bancada) |
| `scripts/game/` | Lógica do balcão, da bancada, do `GameState` (autoload) e do `AtelierSpellJudge` |
| `scripts/game/data/` | Tipos de dados: `AtelierShopDay`, `AtelierScrollOrder`, `AtelierShopRule`, `AtelierConsequence`, `AtelierFlagCondition` |
| `data/days/`, `data/orders/`, `data/rules/` | Conteúdo do demo em `.tres`, editável pelo Inspector |

**Balcão em pixel art (protótipo):** o balcão é desenhado num `SubViewport` de 640x360, com filtro nearest e pixels alinhados, e aparece com escala 2x na janela de 1280x720. A bancada de runas e os cartões do dia continuam em resolução cheia.

- A arte é provisória e original. É gerada por `tools/pixel_art/generate_pixel_art.py`, que produz os sprites, as molduras 9-slice e uma fonte bitmap própria com acentos, em dois tamanhos. Rode o script de novo para ajustar a arte.
- O goblin tem retrato próprio (`portrait` na encomenda). Os demais clientes usam uma silhueta tingida com `portrait_color`.
- A marca APPROVED/REFUSED cai numa área reservada do pergaminho (`StampBox`), sem cobrir texto.
- `tests/pixel_desk_smoke.gd` monta o balcão para todo cliente de todos os dias e confere que nada sai da tela ou se sobrepõe, que a marca fica dentro da área e que a fonte tem todos os caracteres. Rode também com `locale/test="pt_BR"`. Ao criar conteúdo, respeite estes limites: detalhes com até cerca de 4 linhas (~150 caracteres), pedido com até 2 linhas e falas com até 3 linhas.

**Retorno tátil do balcão:** o nó `Feedback` do `Desk` (`AtelierDeskFeedback`) cuida só de animação e som. Ele faz o carimbo voar até o papel, deixa a marca APPROVED/REFUSED, faz a mesa tremer e toca as deixas de som `bell`, `stamp_approve`, `stamp_reject`, `paper` e `coins`.

- A decisão só vale no impacto do carimbo. Os tempos ficam em constantes no topo de `desk_feedback.gd`.
- Os sons atuais são provisórios, gerados em código. Para trocar um deles, arraste o arquivo para `Feedback > sounds` no Inspector.
- Nos testes, `instant = true` faz tudo acontecer na hora, e `mute = true` só anuncia as deixas, sem tocar.

**Idiomas:** o jogo usa a localização nativa do Godot. A tabela `localization/strings.csv`, com uma coluna `en` e outra `pt_BR`, é registrada em `project.godot`.

- O inglês é o fallback. O jogo abre no idioma do sistema quando há tradução para ele (`pt_BR`); nos demais casos, abre em inglês.
- No código, use `tr("CHAVE")` ou `tr("CHAVE") % [args]`. Nas cenas, escreva a chave no `text`; o `Control` traduz sozinho.
- Engine e UI devolvem códigos, e quem mostra o texto chama `tr()`. Os diagnósticos do compilador trazem um `code`, e `AtelierRitualFile` devolve `error` como chave, com `error_args` quando há argumentos.
- Mensagens só de desenvolvimento ficam em inglês simples, marcadas com `# dev-only`, e não entram na tabela. É o caso do overlay F3, dos erros internos de bytecode e da exportação binária, que ainda não tem interface.
- O conteúdo autoral (clientes, regras, dias e manchetes nos `.tres`) não vira chave: é texto em inglês e passa pela tradução automática usando o próprio texto como chave.
- O teste `tests/localization_smoke.gd` confere que toda chave usada existe e resolve em inglês, que nenhuma chave da tabela está sem uso e que nenhum texto fixo sobrou nas chamadas de exibição. Os testes não dependem do idioma ativo.

**Para rodar os testes:** rode `godot --headless --path . --import` uma vez e depois `godot --headless --path . -s tests/<teste>.gd`.

**Para criar um cliente novo:**

1. Duplique um `.tres` em `data/orders/`, dê um `id` único e edite os campos no Inspector.
2. Preencha `examples`, os casos mostrados na bancada, e `hidden_tests`, os casos conferidos só na entrega. Ambos seguem o formato `{"memory": {0: 5}, "output": ["15"]}`, e a memória é lida com `READ`.
   - Pedidos que leem entradas precisam de pelo menos um teste oculto, para que decorar a resposta do exemplo não baste.
   - Se um teste oculto falha, a bancada mostra as entradas dele como pista.
   - `max_steps` é o limite de passos por caso; acima dele, o feitiço é considerado um laço infinito.
   - `starting_ritual` é opcional: um rascunho já desenhado ao abrir a encomenda. **Reset** volta a ele, e `Ctrl+Z` desfaz o reinício.
3. Declare as consequências em `on_delivered`, `on_rejected` e `on_abandoned`. Cada `AtelierConsequence` tem:
   - `delay_days`: `0` aplica na hora, `1` na manhã seguinte.
   - `headline`, que sai no jornal, e `ledger_text`, que entra no livro-caixa.
   - `money`, `reputation` e `flag_changes`, cujos valores são somados às flags.

   A legalidade não é escrita no pedido: ela vem das regras do dia. Para regras sobre a natureza do pedido, use `tags` (por exemplo `offensive` ou `mind`). O jogador não vê as etiquetas e deduz pelo item e pelos detalhes. Pedidos ilegais precisam de pelo menos uma consequência ao serem entregues. A regra geral da loja (pagamento, bônus de elegância e reputação por recusar) fica no `GameState`.
4. Para um cliente condicional, use `conditions`: todas precisam valer para ele aparecer. Para versões alternativas, use `variants`: a primeira variante cujas condições valem toma o lugar do cliente. O inspetor do dia 3 e o retorno do goblin usam esse recurso.
5. Adicione a encomenda ao `orders` de um dia. As variantes não entram na lista, só o cliente base.
6. Coloque a solução de referência em `tests/spell_judge_smoke.gd`, pelo `id`. O teste garante que toda encomenda e toda variante tem solução com as runas do dia, que os ids são únicos e que toda flag usada numa condição é produzida por alguma consequência.

**Para criar uma regra:** crie um `.tres` em `data/rules/` com `AtelierShopRule`, com `id`, `title` (nome curto para o livro-caixa e as provas) e `text`. Em seguida:

- Escolha a verificação em `check`:
  - `FIELD_IS`: um campo igual a um valor, como `race` = `Elf`.
  - `FIELDS_DIFFER`: dois campos diferentes, como `signature` ≠ `name`.
  - `HAS_TAG`: o pedido tem uma etiqueta, como `offensive`.
- Liste em `evidence_fields` os campos que o jogador pode citar como prova.
- Coloque a regra nos `rules` dos dias em que vale.
- Atualize `EXPECTED_BROKEN_RULES` em `tests/spell_judge_smoke.gd`, que fixa quais pedidos devem violar quais regras.

## Estrutura

```text
scenes/
└── Main.tscn                 # Cena principal

scripts/
├── atelier_canvas.gd         # Canvas, interação e interface
└── core/
    ├── atelier_palette.gd    # Paleta do ateliê nos dois temas
    ├── rune_catalog.gd       # Catálogo de selos e opcodes
    ├── rune_diagram.gd       # Estado do diagrama e histórico
    ├── rune_compiler.gd      # Diagrama → instruções → bytecode
    ├── rune_bytecode.gd      # Formato binário RUNE
    └── rune_vm.gd            # Máquina virtual baseada em pilha
```

## Bytecode `RUNE`

O formato binário começa com a assinatura `RUNE`, seguida por uma versão, quantidade de instruções e os opcodes. Cada instrução carrega sua intensidade de `0` a `255`; em instruções como `PUSH`, `STORE`, `LOAD`, `READ`, `WARP` e `PRINTLETTER`, essa intensidade também é o operando numérico.

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
