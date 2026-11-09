# Atelier IDE — contexto do projeto ativo

Atualizado em 2026-10-05. Este arquivo descreve o projeto realmente aberto pelo usuário, não a arquitetura de uma branch histórica.

## Antes de trabalhar

- Leia este arquivo e rode `git status` em `C:\godot\atelier-ide` antes de alterar o projeto.
- O projeto ativo é **`C:\godot\atelier-ide`**. A cena inicial é `scenes/game/Title.tscn`; `scenes/Main.tscn` continua sendo o Sandbox.
- A pasta `C:\godot\atelier-compiler` é uma cópia/worktree separada. Não trabalhar nela presumindo que o usuário verá as alterações. As mudanças do compilador já foram transferidas para o projeto ativo.
- Na integração de 2026-10-05, a branch ativa era `codex/test-no-rune-visuals`, HEAD `1f8351d`, com merge local de `origin/game-case` (`f42ddd6`) sem commit. Confirme o estado atual com Git; não troque de branch sem pedido.
- Preserve as alterações locais, especialmente a integração, o compilador, o diagrama e a interface. Não abortar nem concluir o merge por conta própria.
- **Não fazer commit ou push sem pedido explícito.** Não incluir exportações, executáveis, objetos nem cache do Godot.

## O projeto

IDE em Godot 4 para uma linguagem visual baseada em pilha, inspirada em *Witch Hat Atelier*. O usuário liga pontos de uma grade; cada segmento pode receber uma runa e intensidade de 0 a 255. O desenho é compilado para instruções, bytecode RUNE e/ou assembly NASM.

O editor oferece Play/Pause/Step/Stop, pilha, memória, Oráculo, seleção, histórico, salvar/abrir `.atelier`, temas e exportação `.asm`. O exportador NASM cobre as 30 runas atuais, incluindo portais e alterações de intensidade.

## Modos integrados

- F5 / Run Project abre o menu: **Abrir a loja**, **Sandbox (Atelier IDE)**, configurações e sair.
- Sandbox: editor livre com as 30 runas. **Modo assembly** começa desativado; o checkbox da barra superior habilita File → Exportar assembly NASM. Salvar/abrir e Play funcionam independentemente desse checkbox.
- Loja: demo da `game-case`, com três dias, inspeção de pedidos, regras, consequências, livro-caixa e bancada com as runas liberadas no dia. A bancada não oferece o compilador NASM nem o menu de arquivos.
- Voltar ao menu: File no Sandbox (confirma descarte se houver alterações); configurações na Loja (avisa que Abrir a loja reinicia a partida, pois não há save de campanha).
- A integração não adicionou runas mágicas, estoque ou mana. O juiz ainda compara saída numérica da VM com exemplos e testes ocultos.

## Arquitetura desta cópia

- `scripts/atelier_canvas.gd`: ainda concentra interação, UI, desenho e execução incremental. Esta cópia **não** usa a arquitetura de painéis nativos da antiga `Atelier-ALTER`.
- `scripts/core/rune_diagram.gd`: estado, edição e histórico do grafo.
- `scripts/core/atelier_palette.gd`: cores dos dois temas.
- `scripts/core/atelier_ritual_file.gd`: salvar/abrir JSON `.atelier`.
- `scripts/core/rune_catalog.gd`: 30 símbolos, opcodes, tipos produzidos e efeitos de pilha. Consultas internas usam índices em cache; consultas públicas de símbolos devolvem cópias.
- `scripts/core/rune_compiler.gd`: ordenação do grafo, dependências, instruções com origem e bytecode.
- `scripts/core/rune_bytecode.gd`: RUNE v2, cabeçalho de 7 bytes e 2 bytes por instrução, máximo 65.535 instruções.
- `scripts/core/rune_vm.gd`: máquina virtual baseada em pilha, programa mutável durante execução. `run(bytecode, initial_memory = {}, max_steps = MAX_RUN_STEPS)` aceita entradas da loja e retorna `steps` / `timed_out`.
- `scripts/core/rune_portals.gd`: destinos compartilhados entre VM e análise NASM estática.
- `scripts/core/rune_nasm_exporter.gd`: frontend comum, análise de altura da pilha e geração estática.
- `scripts/core/rune_nasm_mutable.gd`: blocos nativos e estado mutável para `INT_SET` / `INT_MOD`.
- `scripts/core/rune_nasm_common.gd`: emissão binária, erros e limites nativos compartilhados.
- `docs/COMPILADOR.md`: explicação completa do fluxo, regras, exemplos e limitações.
- `scripts/game/` e `scenes/game/`: menu, balcão, bancada, configurações e `GameState` (autoload); `data/` contém dias, pedidos, regras e consequências.
- `scripts/game/spell_judge.gd`: compila o ritual e executa todos os casos da encomenda na VM com memória e limite de passos próprios.
- `localization/strings.csv`: tabela inglês/pt_BR; o Godot importa os recursos `strings.*.translation`, que são gerados e ignorados pelo Git.

## Decisões que devem ser preservadas

- Preservar atlas de runas, cache de texturas/nine-patch dos painéis, culling e otimizações de redraw. Não iniciar uma grande reestruturação da UI sem combinar com o usuário.
- Molduras e cards têm cantos retos: não recortar as imagens para arredondá-las. O desenho circular dos medalhões/glifos não foi removido.
- A área de redimensionamento acompanha toda a lateral dos painéis, não apenas os três pontinhos.
- Preservar edição de pontas: duplo clique alterna a barrinha de mover; traçado contínuo não exige soltar em cada ponto; voltar um ponto remove a última célula; não criar bifurcações ou fechar círculos por nós ocupados.
- A ordem de execução vem da topologia, não da ordem em que as conexões foram inseridas: menor `x`, depois menor `y`, com `HALT` implícito por sequência.
- `PRINT` não remove o topo; `STORE` remove; `READ` lê memória, não teclado.
- `WARP END` único tem prioridade; sem ele, `WARP`s iguais formam anel. Saltos continuam depois do marcador.
- `INT_SET` consome o inteiro de uma produtora posterior e altera a instrução seguinte a ela. `INT_MOD` usa a operação seguinte para alterar o alvo posterior, sem executar essa operação na pilha.
- Alterações de intensidade acontecem na cópia em execução, não reescrevem o ritual editável salvo.
- A UI exporta assembly, não invoca NASM/GCC automaticamente. O assembly é código nativo, não uma função por runa nem um interpretador de opcodes.

## Direção da próxima etapa — ainda não implementada

- Acrescentar runas mágicas, estoque, mana e avaliação de receitas no modo loja, sem limitar o Sandbox nem substituir o compilador nativo.
- A proposta do usuário inclui elemento/poder, projétil/alcance e explosão/raio. Intensidades iniciais custam mana; operações e intensidades mutáveis permitem amplificar o resultado. Essas regras ainda precisam ser implementadas e testadas.
- O compilador foi publicado antes desta integração em `1f8351d`. A integração foi pedida neste prompt, mas novo commit/push não foram autorizados.

## Verificação

Godot console disponível na revisão:

```powershell
$godotConsole = 'C:\Users\Pichau\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File C:\godot\atelier-ide\tools\run_tests.ps1 -GodotPath $godotConsole
powershell -ExecutionPolicy Bypass -File C:\godot\atelier-ide\tools\run_tests.ps1 -GodotPath $godotConsole -Native -RitualPath C:\Users\Pichau\Downloads\fibby.atelier
```

NASM/GCC UCRT64 estão em `D:\msys64\ucrt64\bin`. Os scripts também procuram `C:\msys64` e aceitam `ATELIER_MSYS2_ROOT`; a suíte nativa aceita `ATELIER_NASM_PATH` e `ATELIER_GCC_PATH`.

- Antes da integração: 8 suítes e 56 executáveis comparados com a VM, incluindo `fibby.atelier`.
- Integração validada: 23 suítes (22 smoke + NASM completo), com 56 executáveis comparados com a VM, incluindo `fibby.atelier`. Capturas no renderizador OpenGL também conferiram menu, Sandbox, bancada e configurações.
- A invalidação do cache solicita redesenho: não liberar texturas sem substituir os comandos que ainda as usam, pois isso deixa painéis brancos até outra interação.
- O balcão suspende captura do cache enquanto configurações ou confirmação de saída estão por cima da bancada. Isso evita gravar essas janelas nos painéis ao trocar o idioma. Não capturar canvas oculto.
- `tools/run_tests.ps1` descobre todas as suítes `*_smoke.gd`, incluindo loja e Sandbox; detecta assertions e `SCRIPT ERROR`, mesmo com exit code zero.
- `tests/mode_selection_smoke.gd` testa os botões reais, assembly opt-in, bloqueio de exportação na loja, confirmação de saída e ausência de vazamento de restrições entre modos.
- `tools/test_ritual.gd` testa um `.atelier` pela VM e pelo gerador NASM; argumento de saída opcional grava `.asm`.
- `tools/run_exported_asm.ps1` monta, liga e executa `.asm`, gerando `.obj`/`.exe` ao lado. Pode substituir saídas anteriores de mesmo nome.
- A integração corrigiu a configuração para `localization/strings.en.translation` e `strings.pt_BR.translation`, gerados do CSV. Importar o projeto no Godot antes dos testes numa cópia nova.
- A VM de testes e o backend mutável limitam a execução a 10.000 passos. O Play e o backend estático não têm esse mesmo contador global. Pilha NASM: máximo 256 valores.

## Histórico, não instruções da arquitetura atual

`Atelier-ALTER` recebeu uma refatoração antiga com UI nativa separada. A referência visual do amigo era `origin/claude/arcanum-editor-ide-style-2303a5` (`fcd9a21`). Depois o trabalho seguiu na branch de testes baseada nesse visual, com atlas, cache de painéis e compilador. Não assumir que arquivos `scripts/ui/*`, `compiler.gd` ou `ritual_vm.gd` daquela refatoração existam na cópia ativa.
