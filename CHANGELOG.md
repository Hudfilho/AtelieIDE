# Patch notes — grande atualização do Atelier IDE

## Visual e desempenho

- O ateliê ganhou o visual arcano de couro, latão e pergaminho, com temas claro e escuro; a escolha do tema é lembrada entre sessões.
- As runas passaram a ser carregadas de um atlas de imagens pré-renderizadas, evitando reconstruir seus traços a cada quadro.
- Molduras reutilizáveis e cache dos painéis reduzem o redesenho da interface. Os painéis continuam redimensionáveis.
- O diagnóstico de desempenho (`F3`) mostra FPS, tempos de desenho e quantidade de células visíveis. `F6` alterna o cache dos painéis e `F7` alterna a camada visual para comparação.

## Arquivos e execução

- O menu **File** permite salvar e abrir rituais editáveis no formato `.atelier`, incluindo células, runas, intensidades, posição da câmera e zoom.
- `Ctrl+S` e `Ctrl+O` são atalhos para salvar e abrir. Antes de abrir outro ritual com alterações não salvas, o editor pede confirmação.
- **Passar para Assembly** aparece no menu como uma opção desabilitada, reservada para uma futura implementação.
- Ao apertar Play, o compilador detecta dependências inválidas de `WARP`, `WARP END`, `JUMP_IF_TRUE`, `INT_MOD` e `INT_SET` antes de executar. Erros são explicados no Oráculo e a célula correspondente recebe uma marca vermelha discreta. Erros encontrados durante a execução também são localizados.

## Traçado e edição dos nós

- Segurar e arrastar a partir de uma ponta livre adiciona células conforme o cursor passa pelos pontos da grade, sem precisar soltar a cada célula.
- Voltar ao ponto imediatamente anterior durante o traçado apaga a última célula. A ação pode ser desfeita com `Ctrl+Z`.
- Um duplo clique na ponta alterna o modo persistente de mover. Uma barrinha perpendicular à linha indica que arrastar aquela ponta a desloca, em vez de criar células.
- Junções continuam podendo ser movidas para pontos livres, mas não podem iniciar novas células. Ligações e movimentos para nós já ocupados são bloqueados, evitando ramificações e círculos acidentais.

## Verificação

- Testes automatizados cobrem salvar/abrir, diagnósticos de runas, o modo de mover pontas, traçado contínuo, retorno que apaga a última célula e bloqueio de nós ocupados.
