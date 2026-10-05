# Patch notes — grande atualização do Atelier IDE

## Visual e desempenho

- O ateliê ganhou o visual arcano de couro, latão e pergaminho, com temas claro e escuro; a escolha do tema é lembrada entre sessões.
- As runas passaram a ser carregadas de um atlas de imagens pré-renderizadas, evitando reconstruir seus traços a cada quadro.
- Molduras reutilizáveis e cache dos painéis reduzem o redesenho da interface. Os painéis continuam redimensionáveis.
- Molduras e cards usam cantos retos para não recortar as texturas. A área de puxar/redimensionar acompanha toda a lateral dos painéis.
- O diagnóstico de desempenho (`F3`) mostra FPS, tempos de desenho e quantidade de células visíveis. `F6` alterna o cache dos painéis e `F7` alterna a camada visual para comparação.

## Arquivos e execução

- O menu **File** permite salvar e abrir rituais editáveis no formato `.atelier`, incluindo células, runas, intensidades, posição da câmera e zoom.
- `Ctrl+S` e `Ctrl+O` são atalhos para salvar e abrir. Antes de abrir outro ritual com alterações não salvas, o editor pede confirmação.
- **Exportar Assembly NASM** está habilitado no menu File e salva código nativo para Windows x86-64.
- Ao apertar Play, o compilador detecta dependências inválidas de `WARP`, `WARP END`, `JUMP_IF_TRUE`, `INT_MOD` e `INT_SET` antes de executar. Erros são explicados no Oráculo e a célula correspondente recebe uma marca vermelha discreta. Erros encontrados durante a execução também são localizados.

## Compilador e ferramentas

- As 30 runas atuais têm tradução NASM, incluindo memória, comparações, booleanos, portais, `INT_SET` e `INT_MOD`.
- Programas sem intensidades mutáveis usam análise estática da pilha e geração direta de instruções. Programas mutáveis usam blocos nativos, estado de intensidade e saltos dinâmicos, sem função por runa nem interpretador de bytecode no executável.
- VM e análise NASM compartilham as regras de destinos dos portais; os backends compartilham a emissão das operações binárias e os limites nativos.
- O catálogo usa índices em cache e centraliza requisitos/efeitos de pilha, evitando cópias desnecessárias durante as consultas de execução.
- Bytecode RUNE rejeita dados inválidos, truncados ou excedentes e programas acima de 65.535 instruções. Salvamento e exportação verificam falhas de gravação.
- `tools/run_exported_asm.ps1` monta, liga e executa o assembly com NASM/GCC UCRT64 do MSYS2.
- `tools/run_tests.ps1` reúne os testes do projeto; `-Native` compara executáveis reais com a VM.
- `docs/COMPILADOR.md` explica o frontend visual, IR, bytecode, VM, semântica das runas e os dois caminhos NASM, com exemplos e limitações.

## Traçado e edição dos nós

- Segurar e arrastar a partir de uma ponta livre adiciona células conforme o cursor passa pelos pontos da grade, sem precisar soltar a cada célula.
- Voltar ao ponto imediatamente anterior durante o traçado apaga a última célula. A ação pode ser desfeita com `Ctrl+Z`.
- Um duplo clique na ponta alterna o modo persistente de mover. Uma barrinha perpendicular à linha indica que arrastar aquela ponta a desloca, em vez de criar células.
- Junções continuam podendo ser movidas para pontos livres, mas não podem iniciar novas células. Ligações e movimentos para nós já ocupados são bloqueados, evitando ramificações e círculos acidentais.

## Verificação

- Testes automatizados cobrem salvar/abrir, diagnósticos de runas, o modo de mover pontas, traçado contínuo, retorno que apaga a última célula e bloqueio de nós ocupados.
- A revisão passou 8 suítes, incluindo 56 executáveis comparados com a VM e o Fibonacci do usuário. Os testes também cobrem catálogo, bytecode, geometria dos painéis, todas as runas NASM e casos de erro.
- Permanecem avisos preexistentes de traduções ausentes na configuração local do Godot; eles estão documentados e não impedem os testes.

## Próxima etapa planejada, não incluída nesta versão

- Preservar o editor livre em um modo **Sandbox**, com assembly opcional, separado das regras de estoque e mana do modo loja.
- Integrar o core da loja da branch `game-case` e acrescentar runas mágicas e avaliação de receitas de feitiços. Essa integração foi adiada explicitamente para o próximo prompt.
