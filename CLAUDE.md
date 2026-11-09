# Atelier IDE — instruções para Claude Code

O projeto real é `C:\godot\atelier-ide`. Trabalhe nessa pasta, a mesma aberta no Godot do usuário. A cópia `C:\godot\atelier-compiler` não é o projeto ativo. Não crie clone/worktree automaticamente.

Antes de editar:
1. Leia completamente `C:\godot\atelier-ide\PROJECT_CONTEXT.md`.
2. Leia `C:\godot\atelier-ide\HANDOFF_CLAUDE.md`, que registra o foco mais recente do usuário e distingue requisitos de propostas ainda não confirmadas.
3. Rode `git status`. Preserve os arquivos locais e o índice.

Não fazer commit/push, reset ou troca de branch sem pedido explícito. Em 09/11/2026, a pedido do usuário, o merge pendente (`origin/game-case` em `codex/test-no-rune-visuals`) foi concluído num commit e publicado: `main`, local e no GitHub, aponta para esse commit e é a branch de trabalho.

Foco atual: desenvolver runas mágicas que, quando executadas, alimentam uma pilha mágica separada, usada para determinar o feitiço no cast. Deixar a loja/campanha de lado nesta etapa. Fogo, Projétil e Explosão são os exemplos iniciais; regras de repetição e composição ainda precisam ser consolidadas com o usuário.

Preserve o compilador das 30 runas existentes, arquivos antigos, atlas e cache dos painéis, cantos retos, redimensionamento e edição dos nós. A exportação NASM deve tratar explicitamente runas mágicas, sem ignorá-las silenciosamente.

Valide mudanças relevantes com Godot local e `C:\godot\atelier-ide\tools\run_tests.ps1`. Caminhos, comandos e histórico de testes estão no handoff. Atualize os documentos ao consolidar decisões.
