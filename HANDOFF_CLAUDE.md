# Handoff para Claude — Atelier IDE / pilha mágica

Preparado em 07/11/2026. Este documento registra o pedido mais recente do usuário e distingue requisitos de sugestões discutidas. Continue trabalhando sobre os arquivos existentes.

## Entrada e estado do repositório

- Projeto real: `C:\godot\atelier-ide`, aberto pelo usuário no Godot.
- Antes de editar, leia `C:\godot\atelier-ide\PROJECT_CONTEXT.md` e rode `git status` nesse diretório. Este handoff atualiza o foco de trabalho descrito naquele contexto antigo.
- Não trabalhar em `C:\godot\atelier-compiler`, outra cópia/worktree.
- Em 07/11/2026: branch `codex/test-no-rune-visuals`, HEAD `1f8351d`; MERGE_HEAD `f42ddd6`, de `origin/game-case`.
- O merge está resolvido, mas ainda sem commit. Havia 365 arquivos preparados no índice antes destes documentos. São melhorias existentes, não lixo para limpar.
- Preserve o índice e os arquivos locais. Não abortar/concluir merge, trocar de branch, fazer reset, commit ou push sem pedido explícito.
- Trabalhe na pasta atual para o usuário ver as alterações no projeto aberto. Não crie clone ou worktree automaticamente.

## Pedido atual do usuário — fonte de verdade

O usuário pediu para deixar a integração com a loja de lado e desenvolver o sistema de runas mágicas:

> Runas mágicas, quando executadas, colocam propriedades numa pilha separada chamada pilha mágica. Quando decidimos castar o spell, essa pilha determina seu efeito. Exemplos: fogo e projétil. Todas podem ter intensidade, determinando a força da propriedade.

Exemplos já discutidos pelo usuário ao longo do projeto:
- Fogo: elemento/poder mágico conforme a intensidade.
- Projétil: forma de lançamento, com alcance conforme a intensidade.
- Explosão: explosão do elemento escolhido, com raio conforme a intensidade.
- Futuramente, operações e INT_SET/INT_MOD permitirão obter propriedades fortes a partir de poucos recursos iniciais.

O objetivo agora é desenvolver esse núcleo no editor. Loja, clientes, mana, estoque, bestiário e campanha ficam fora da primeira entrega.

## Proposta anterior do assistente — ainda não confirmada pelo usuário

Foi sugerido um protótipo com Fogo, Projétil e Explosão, um painel da pilha mágica e um botão Castar. A primeira resposta do cast poderia ser uma descrição estruturada do feitiço, antes de criar efeitos visuais no mundo.

Exemplo ilustrativo:
`[Fogo: 80, Projétil: 30, Explosão: 15]`
Poderia representar fogo de poder 80, projétil de alcance 30 e explosão de raio 15 no impacto.

Também foram sugeridos, mas NÃO aprovados como regras definitivas:
- Categorias elemento, forma e comportamento.
- Prevalecer o último elemento/forma executado, enquanto comportamentos diferentes se combinam.
- Exigir um elemento e uma forma para castar.
- Limpar a pilha mágica no início de uma nova execução.

Não apresente essas sugestões como decisões do usuário. Antes de consolidar o comportamento, deixe claras suas escolhas para propriedades repetidas, ordem, mistura de elementos, consumo da pilha no cast e diferença entre um cast e vários casts. Se isso mudar materialmente a experiência, alinhe a regra com o usuário.

## Ponto técnico central

As propriedades entram na pilha quando a instrução realmente executa, usando sua intensidade naquele momento. Não montar o resultado varrendo todas as runas desenhadas: saltos, condições, loops e mutação de intensidade devem influenciar o feitiço produzido.

A pilha numérica e a pilha mágica são estados distintos. Para o protótipo proposto, uma runa mágica pode adicionar um registro de propriedade sem consumir números; confirme as regras que escolher. Considere preservar a origem da instrução para diagnósticos e exibição.

## O que já funciona e deve ser preservado

Linguagem visual de pilha em Godot 4, com 30 runas, intensidade 0–255, execução incremental, Play/Pause/Step/Stop, pilha numérica, memória e Oráculo. Possui histórico, salvar/abrir JSON `.atelier`, exportação bytecode RUNE v2 e assembly NASM Windows x86-64.

O menu inicial é `C:\godot\atelier-ide\scenes\game\Title.tscn`. F5 / Run Project abre Loja ou Sandbox. O Sandbox é `C:\godot\atelier-ide\scenes\Main.tscn`, livre com 30 runas; checkbox Modo assembly habilita exportação NASM. A loja integrada tem três dias e avalia saídas numéricas da VM, mas não é o foco atual.

Semântica existente:
- Execução ordenada pela topologia, não pela ordem de criação; HALT implícito por sequência.
- PRINT mantém o topo; STORE remove; READ lê memória, não teclado.
- WARP END único tem prioridade; sem ele, WARPs da mesma intensidade formam anel. Salto continua depois do marcador.
- INT_SET e INT_MOD têm regras próprias de dependências. Leia a documentação e preserve-as; alterações atingem a cópia em execução, não o ritual salvo.
- O NASM atual tem geração estática e mutável, cobrindo as 30 runas computacionais. Não é um interpretador nem uma função executada para cada runa.

Ao adicionar runas mágicas, preserve os IDs existentes e a leitura de arquivos antigos. Verifique catálogo, compilador, bytecode, VM, salvamento e atlas. A intensidade efetiva de uma runa mágica deve poder participar do mecanismo de alteração de intensidade sem declará-la indevidamente uma produtora de inteiro na pilha numérica.

Decida explicitamente como a exportação NASM trata instruções mágicas. Uma rejeição explicativa é preferível a ignorar instruções silenciosamente ou gerar um arquivo incorreto. Preserve a compilação dos programas antigos com as 30 runas.

## Arquivos para inspecionar

- `C:\godot\atelier-ide\scripts\atelier_canvas.gd`: interação, UI, desenho e execução incremental. Ainda é um arquivo grande; não presumir a arquitetura da antiga Atelier-ALTER.
- `C:\godot\atelier-ide\scripts\core\rune_catalog.gd`: símbolos, opcodes, operandos, tipos e efeitos de pilha.
- `C:\godot\atelier-ide\scripts\core\rune_compiler.gd`: topologia, validação, IR e bytecode.
- `C:\godot\atelier-ide\scripts\core\rune_bytecode.gd`: formato RUNE v2.
- `C:\godot\atelier-ide\scripts\core\rune_vm.gd`: estado e execução. `run(bytecode, initial_memory = {}, max_steps = MAX_RUN_STEPS)`.
- `C:\godot\atelier-ide\scripts\core\rune_diagram.gd`: edição/histórico.
- `C:\godot\atelier-ide\scripts\core\atelier_ritual_file.gd`: persistência `.atelier`.
- `C:\godot\atelier-ide\scripts\core\rune_nasm_exporter.gd`: geração NASM e seleção do backend.
- `C:\godot\atelier-ide\docs\COMPILADOR.md`: explicação detalhada das regras.
- `C:\godot\atelier-ide\localization\strings.csv`: UI inglês/pt_BR; traduções binárias são importadas pelo Godot.

## Desempenho e aparência

O PC da faculdade do usuário tem dificuldades reais com o desenho da UI. Preservar atlas pré-renderizado das runas, cache dos painéis/nine-patch, culling e redraw sob demanda. Ao ampliar o catálogo, reaproveite a linguagem visual e o pipeline de atlas; não invente símbolos desconectados dos significados.

Preservar cantos retos de molduras/cards e redimensionamento por toda a lateral. Desenho do ritual deve ficar atrás dos painéis. Cache usa coordenadas corretas quando o editor está embutido na bancada; invalidar texturas deve provocar redraw. Não capturar canvas oculto nem gravar modais sobre os painéis.

Preservar edição de linhas: traçado contínuo, voltar um ponto apaga a última célula, duplo clique na ponta alterna modo de mover com barrinha perpendicular, mover junções para pontos livres e bloqueio de bifurcações/círculos por nós ocupados.

## Validação e ferramentas locais

Última rodada da implementação anterior: 22 smoke + NASM completo (23 suítes), 56 executáveis comparados com a VM, incluindo Fibonacci. Telas também foram conferidas em OpenGL. Não são testes reexecutados nesta preparação de handoff.

Godot console confirmado disponível:
`C:\Users\Pichau\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

PowerShell:
```powershell
$atelierGodot = 'C:\Users\Pichau\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $atelierGodot --headless --editor --path 'C:\godot\atelier-ide' --quit
& 'C:\godot\atelier-ide\tools\run_tests.ps1' -GodotPath $atelierGodot
# Se alterar o compilador/backend, inclua a validação nativa:
& 'C:\godot\atelier-ide\tools\run_tests.ps1' -GodotPath $atelierGodot -Native -RitualPath 'C:\Users\Pichau\Downloads\fibby.atelier'
```

NASM/GCC em `D:\msys64\ucrt64\bin`. O teste nativo usa executáveis locais temporários. Para iniciar o projeto pelo terminal: `& $atelierGodot --path 'C:\godot\atelier-ide'`.

Para a nova funcionalidade, valide em especial execução condicional/repetida de runas mágicas, intensidade efetiva após mutação, isolamento da pilha numérica, política de reset/cast escolhida, salvar/reabrir e comportamento NASM explícito. Confira também o painel na renderização real, pois headless não revelou alguns bugs de cache anteriores.

## Como começar a próxima sessão

Leia contexto e código, confirme o Git e proponha um fluxo concreto de execução → pilha mágica → cast. Trate sugestões acima como escolhas abertas. Quando for implementar, faça um protótipo pequeno e testável no Sandbox, mantendo a lógica do feitiço separada do desenho da UI. Registre decisões e limitações nos documentos do projeto para a próxima continuação.

## Atualização 08/11/2026 — estado atual (substitui o foco acima onde houver conflito)

O usuário redirecionou o trabalho várias vezes depois deste handoff. Estado no fim da madrugada de 08/11:

- **Cena principal**: `scenes/ware/Hub.tscn` (menu: JOGAR, TREINAR, COMO JOGAR, ARENA DAS BOLINHAS, EDITOR LIVRE). O Sandbox (`scenes/Main.tscn`) continua intocado, a pedido do usuário. O menu antigo da loja (`scenes/game/Title.tscn`) não é mais a entrada.
- **Arena das bolinhas** (`scripts/arena/`): jogo top-down com runas mágicas, orbes de vidro, raridade, portal frágil e mana por execução. Regras e decisões na nota 14 do vault (`docs/atelier-vault/14 Runas Mágicas — Mudanças para o Jogo.md`).
- **Atelier Ware** (`scripts/ware/`, `scenes/ware/`): 12 microjogos estilo WarioWare resolvidos com rituais (pedido do usuário: "faz uns 10 assim... tipo um wario ware"). Runas de ação novas `0x30`–`0x39` (só modo jogo; NASM recusa). Regras, decisões tomadas sem o usuário e perguntas em aberto na nota 15 do vault (`docs/atelier-vault/15 Atelier Ware — Microjogos.md`).
- **Testes**: `tests/ware_smoke.gd` (todo desafio de todo nível tem ritual que vence passando pelo compilador e pela VM, dentro dos limites; fontes; editor; chefão) e `tests/arena_flow_smoke.gd`. Os testes antigos da loja (`mode_selection_smoke`, `title_smoke` e afins) esperam a loja como entrada e vão falhar no `run_tests.ps1` até a loja ser descartada ou os testes ajustados.
- Git (09/11/2026, a pedido do usuário): o merge de `origin/game-case` foi concluído num commit junto com todo o trabalho acima e publicado. `main` (local e `origin`) aponta para esse commit e é a branch de trabalho; `codex/test-no-rune-visuals` ficou no mesmo commit.

