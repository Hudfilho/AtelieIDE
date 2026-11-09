---
tags: [jogo, runas-magicas, em-aberto]
status: rascunho
---
# 14 — Runas mágicas: o que muda na linguagem para o jogo

> [!todo] Nota em aberto
> Esta nota será preenchida quando o modo de combate estiver implementado. O que está aqui são as **decisões já tomadas**, as **perguntas abertas** e os **pontos do compilador que vão ser tocados**. Não trate as seções vazias como regras.

## Visão do jogo (direção, novembro/2026)

- Combate **top-down**. O jogador tem runas limitadas, desenha feitiços no editor e os guarda em **bolinhas**.
- Bolinhas são soltas no campo e executam seus efeitos. Sem feitiços = morte; limpar a sala = mais runas + reembolso parcial.
- **Intensidade** vira recurso: consome uma barra de **mana** que só recarrega na próxima luta.
- Runas mágicas têm **raridade**, que multiplica a potência.

## Conceito central já decidido

Runas mágicas, ao **executar** (não ao serem desenhadas), empilham propriedades numa **pilha mágica separada** da pilha numérica. Ao **castar**, essa pilha define o feitiço. Saltos, condições, loops e `INT_SET`/`INT_MOD` influenciam o resultado porque só o que executa entra na pilha.

## Runas propostas (exemplos do usuário)

| Runa | Efeito | Intensidade | Raridade |
|---|---|---|---|
| Explosão de fogo | Explosão com alcance e dano | alcance/dano | multiplica intensidade |
| Projétil | Fonte do feitiço se move até o alvo mais próximo | distância | não tem |
| Duplicar | Repete a próxima runa 2× | — | ? |
| Warp (jogo) | Igual ao `WARP`, mas **quebra** após N usos | id do portal | define N |

## Perguntas em aberto (responder antes de implementar)

- [ ] A pilha mágica é uma **receita** (propriedades combinadas num efeito) ou uma **linha do tempo** (efeitos em sequência: anda X, depois explode R)?
- [ ] Mana é cobrada da intensidade **inicial** (desenhada) ou **efetiva** (após `INT_MOD`)? A exploração do compilador só vale a pena se for da inicial.
- [ ] Warp que quebra: os usos contam **por cast** ou **pela luta inteira**? Pela luta exige runa como *instância* com durabilidade no inventário.
- [ ] Duplicar repete a próxima **instrução** (inclusive numérica) ou só a próxima **propriedade mágica**?
- [ ] Propriedades repetidas (dois Fogos): somam, prevalece a última, ou viram dois efeitos?
- [ ] A pilha mágica é limpa a cada Play? Um ritual pode produzir mais de um cast?

## Pontos do compilador que serão tocados

| Módulo | Mudança prevista | Nota |
|---|---|---|
| [[02 Catálogo de Runas]] | Novos símbolos com opcode ≥ `0x1f` e uma flag `magic: true`. **Sem** `result_type: "int"`. | fácil |
| [[06 Máquina Virtual]] | `state["magic"]` (array de `{kind, intensity, connection_index}`), flag de Duplicar, contador de usos de portal. | fácil |
| [[08 INT_SET e INT_MOD]] | Nada: `_set_instruction_intensity` já é genérica; runas mágicas viram alvos válidos. | grátis |
| [[05 Bytecode RUNE v2]] | Nada, enquanto couber em `[opcode][intensidade]`. | grátis |
| [[01 Diagrama e Arquivo .atelier]] | Nada no formato; arquivos antigos seguem abrindo. | grátis |
| [[09 Backend NASM Estático]] / [[10 Backend NASM Mutável]] | **Rejeitar explicitamente** rituais com opcodes mágicos, com mensagem clara. Não ignorar. | fácil |
| [[11 Execução no Editor (Play)]] | Painel da pilha mágica + botão Castar, lendo `state["magic"]`. | médio (canvas) |
| Novo: `scripts/core/spell_cast.gd` | Pilha mágica → lista de efeitos (puro, testável sem UI). | fácil |
| Novo: cena de arena | Bolinha executa a lista de efeitos; inimigos; mana; recompensa. | **o grosso do trabalho** |

## Registro de decisões

_(preencher conforme forem fechadas, com data)_

- 2026-11-07 — Loja (`game-case`) será descartada após fechar o merge; infra de menu, idioma, `VM.run(memory, max_steps)` e runner de testes fica.
- 2026-11-07 — **Protótipo implementado (regras provisórias, escolhidas por Claude, a confirmar):**
  - Opcodes `0x1f` FIRE, `0x20` PROJECTILE, `0x21` EXPLOSION em `MAGIC_SYMBOLS`, fora de `SYMBOLS` (Sandbox continua com 30). Sem `result_type`.
  - VM: `state["magic"]` recebe `{kind, intensity efetiva, connection_index}` quando a runa executa; `run()` devolve `magic`.
  - NASM: recusa explícita de runas mágicas.
  - Pilha mágica = **linha do tempo** (`scripts/arena/spell_rules.gd`): FOGO vale para explosões depois dele (soma intensidade ao dano); PROJÉTIL anda até o inimigo mais próximo (24 + 2,5×int px); EXPLOSÃO explode onde a orbe está (raio 20 + 1,1×int, dano int + fogo).
  - Mana = soma das intensidades **desenhadas** (antes de INT_SET/INT_MOD); 200 por luta; sala limpa recarrega.
  - Runa recém-colocada no jogo nasce com intensidade 20.
  - Editor em `pixel_hud` (export no canvas, padrão desligado) + HUD em `scripts/arena/spell_creation.gd`.
  - Ainda não feito: Duplicar, Warp que quebra, raridade, inventário de runas.
- 2026-11-07 — **APLICAR** (`INT_APPLY`, opcode `0x22`, só no modo jogo, fora do Sandbox e do NASM): tira o topo da pilha numérica, limita a 0–255 e o aplica como intensidade da instrução seguinte, que executa logo depois. Sem alvo na mesma sequência = erro de compilação. Substitui INT_SET/INT_MOD na paleta do jogo (as duas continuam na linguagem).
- 2026-11-07 — Custo de mana passa a contar só runas cuja intensidade tem efeito (operandos e mágicas). Valores calculados na pilha e aplicados com APLICAR não custam.
- 2026-11-07 — **Loop da run** (`scripts/arena/arena.gd`): bolsa de runas limitada (8 tipos no início); runa no desenho usa uma da bolsa; confirmar gasta mana e runas (vão para a orbe, o desenho fica só com as linhas). Sala limpa: volta metade das runas lançadas, +1 Explosão, escolhe 1 de 3 runas (as que ainda não tem saem 3x mais). Sala n: 3+n esqueletos (máx. 12), vida 30+12(n−1), mana 200+20(n−1). Fim: sem orbe, sem bolinha rolando e sem Explosão ou sem mana.
- 2026-11-07 — Runas novas do jogo: **GELO** `0x24` e **RAIO** `0x25` (elementos, como FOGO; usam os shaders do Codex), **DUPLICAR** `0x23` (a próxima instrução executa mais uma vez; acumula; não repete se ela saltar). Paleta do jogo = 32 runas (mágicas + computacionais da linguagem).
- 2026-11-07 — **Rebalanceamento do começo:** só runas mágicas (+ Duplicar) são gastas; runas de lógica liberadas são infinitas (recompensa "NOVA"). Início: 6 Explosões, 4 Projéteis, 2 Fogos + Número/Copiar/Somar/Subtrair/Multiplicar/Aplicar infinitos, e uma orbe pronta (Projétil 40, Fogo 20, Explosão 30). Sala n: 2+n esqueletos, vida 20+10(n−1) — a Explosão padrão (20) mata na sala 1. Recompensa mágica: Explosão +3, outras +2.
- 2026-11-07 — **Portal frágil** (`WARP_FRAGILE`, `0x26`, só no jogo): mesma regra de destino do WARP (`rune_portals.gd` agrupa os dois), mas quebra depois de 2 saltos por execução (Rara 3, Épica 5, Lendária 8) e vira passagem. Substitui o Portal na paleta do jogo; é gasto como as mágicas. O WARP do Sandbox não mudou.
- 2026-11-07 — **Raridade** (`scripts/arena/rarity.gd`): Comum ×1, Rara ×1,5, Épica ×2, Lendária ×3 na intensidade de Explosão, Fogo, Gelo e Raio (Projétil não tem). Fica na célula (`connection["rarity"]`), vai para a instrução do compilador mas não para o bytecode; o modo jogo roda `VM.run_program(instruções)` para manter célula e raridade. Bolsa: uma pilha por raridade (`"EXPLOSION#2"`). Mana cobra o valor desenhado, então raridade é potência grátis. Recompensas sorteiam raridade (60/27/10/3%, melhora por sala).
- 2026-11-08 — **Atelier Ware** (ver [[15 Atelier Ware — Microjogos]]): 10 runas de ação (`0x30`–`0x39`, só no jogo) que entram na pilha mágica como as mágicas; a VM trata todo opcode mágico no mesmo ramo. 10 microjogos em sequência estilo WarioWare, Treino e um menu inicial (`scenes/ware/Hub.tscn`, nova cena principal) que leva à Arena e ao Editor livre. Esc na Arena volta ao menu.
