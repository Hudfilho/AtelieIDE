---
tags: [limitacoes]
---
# 13 — Limitações conhecidas

- **Um único alvo nativo**: Windows x86-64, NASM. Linux/ARM exigiriam outro backend.
- **Sem phi**: o backend estático rejeita convergências com alturas de pilha diferentes. Não há propagação de constantes nem alocação de registradores.
- **Pilha nativa de 256 valores.** A VM não tem limite de pilha.
- **Passos**: `VM.run` e o backend mutável param em 10.000; o Play do editor e o backend estático **não** têm contador global.
- **Dependências mutáveis** nem sempre são prováveis estaticamente; a VM/backends validam em runtime.
- **Overflow extremo** de 64 bits não é coberto por testes de equivalência VM ↔ nativo.
- **`.rune` existe na API** (`export_binary`), mas o menu só oferece `.atelier` e `.asm`.
- **`atelier_canvas.gd` monolítico**: qualquer painel novo passa por ele. Lógica nova deve ficar em `scripts/core/` ou `scripts/game/`, com o canvas só exibindo.
- **Loja integrada** (`game-case`) ainda está no repositório, mas o rework de novembro/2026 a substitui por combate top-down. Ver [[14 Runas Mágicas — Mudanças para o Jogo]].
