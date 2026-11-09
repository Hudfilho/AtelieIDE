# 15 Atelier Ware — Microjogos

Coleção de microjogos no estilo WarioWare em que cada desafio é resolvido **desenhando um ritual de runas**. Usa o mesmo editor do modo jogo (`spell_creation.gd` em modo ware), o mesmo compilador e a mesma VM. Nada mudou no Sandbox.

## Como a linguagem encaixa

- **Runas de ação** (`ACTION_SYMBOLS`, opcodes `0x30`–`0x39`): Cima, Baixo, Esquerda, Direita, Pular, Pintar, Tocar sino, Girar, Atirar, Mirar. Funcionam como as runas mágicas: ao executar, empilham `{kind, intensity}` na pilha mágica (`state["magic"]`) e não tocam na pilha numérica. A **intensidade** é o parâmetro da ação (casas, ângulo, nota, cor, graus, força).
- São só do modo jogo (`is_game_only`): ficam fora do Sandbox, do atlas e do NASM, que recusa com mensagem.
- A VM trata qualquer opcode mágico no ramo genérico (`RuneCatalog.is_magic`), então runa nova de ação não exige código na VM.
- **Laço infinito não é erro** no modo ware: a VM para no limite de passos, as ações param em 300 e o microjogo decide quando o objetivo foi cumprido (pegou a última moeda, ganhou na hora).
- Saída numérica (Entregar) também vale: o Número Mágico lê `output`.

## Arquitetura

| Arquivo | Papel |
|---|---|
| `scripts/ware/microgame.gd` | Base: textos, paleta, limites, `build(level)`, `reset_world()`, `execute(actions, output)` (corrotina), `solution()`/`solution_program()` e ajudantes de desenho pixel. |
| `scripts/ware/games/*.gd` | Os 12 microjogos. |
| `scripts/ware/ware_runner.gd` + `scenes/ware/Ware.tscn` | Sequência: vidas, cronômetro, nível, editor com a transição da orbe, resultado. Também o Treino. |
| `scripts/ware/hub.gd` + `scenes/ware/Hub.tscn` | Menu inicial (cena principal). |
| `tests/ware_smoke.gd` | Prova que todo desafio tem solução dentro dos limites, passando pelo compilador e pela VM. |

## Regras do modo (decididas por Claude, a confirmar)

- 4 vidas. Cronômetro de 90 s no nível 1, −10 s por nível, mínimo 40 s, mais 3 s por runa que a solução pede além de 6. O tempo corre com o editor aberto e para nos primeiros 6 s de animação do ritual (depois volta a correr: um laço sem fim não trava a partida). ESPAÇO, ESC ou o botão PARAR interrompem o ritual e recomeçam o mesmo desafio com o desenho intacto.
- Errou: o mundo volta ao começo e o desenho continua no editor para ajustar. Tempo acabou: perde uma vida.
- Nível = 1 + vitórias / 3 (máx. 5). Animações 15% mais rápidas por nível.
- Jogos sorteados em "saco embaralhado" (todos aparecem antes de repetir).
- A cada 10 microjogos vem um **CHEFÃO**: um nível acima, 50% mais tempo; vencer devolve uma vida.
- Na sequência, sair pede ESC duas vezes (a partida acaba). No treino, um ESC volta ao menu.
- Intensidade no editor: barra, botões − e +, ou digitar o número com a runa selecionada; setas vão de 0 a 20 (antes 0 a 255).
- LIMPAR (embaixo do VOLTAR) volta o desenho para a linha vazia.
- O editor já abre com uma **linha vazia** (casas marcadas) do tamanho da solução + 3, com zoom 1,5: o jogador só solta as runas e ajusta a intensidade.
- Nos primeiros 7 s de cada microjogo o objetivo aparece numa faixa no alto.
- Errou: o motivo diz o que corrigir quando dá ("Faltou força: caiu antes do alvo", "Caiu: pulo curto", "Bateu no muro: mire mais alto").
- Treino: um jogo, sem tempo nem vidas; cada vitória sobe o nível daquele jogo.
- Recorde salvo em `user://atelier_ware.cfg`.

## Os microjogos (12)

| Jogo | Ordem | Runas | O que a progressão pede |
|---|---|---|---|
| Labirinto | Chegue na saída | setas, Duplicar, Portal | labirinto maior; do nível 4 em diante a porta pede a chave (num desvio de 2 a 4 casas) |
| Cavaleiro Saltador | Pule até a bandeira | Direita/Esquerda (8 px por ponto), Pular (intensidade = ângulo) | mais pulos; plataformas geradas a partir de pulos simulados |
| Caixas | Empurre as caixas | setas, Duplicar | mapas feitos à mão ou gerados de trás para a frente (caixas puxadas a partir das marcas); 2 caixas no fim |
| Moedas | Pegue as moedas | setas, Duplicar, Portal | poucas setas: repetir o caminho com Portal; desenhos espelhados ao acaso |
| Canhão | Acerte o alvo | Mirar (ângulo), Atirar (força) | 1 tiro, muro na frente, alvo menor; vento no nível 5 (biruta mostra direção e força) |
| Sinos | Toque a melodia | Tocar sino (nota), Duplicar, Portal | a melodia toca uma vez no começo; poucos sinos: Duplicar e Portal |
| Pintor | Copie o desenho | setas, Pintar (molha o pincel na cor 1–3; 0 levanta) | o pincel molhado pinta por onde anda (tartaruga do Logo); mais traços e cores |
| Torreta | Quebre os cristais | Girar (graus, até 180), Atirar, Duplicar | ângulos de 45 → 30 → 15, munição exata; do nível 4 em diante um cristal fica atrás de outro (dois tiros na mesma linha) |
| Número Mágico | Entregue o número | Número (até 9), Copiar, Somar, Subtrair, Multiplicar, Entregar | a+b → a×b → a×b±c → a×b×c ou a²+b |
| Esqueletos | Defenda a muralha | Projétil (fileira), Duplicar | mais esqueletos e mais rápidos; de elmo aguentam 2 tiros |
| Fogueiras | Acenda as tochas | setas, Fogo (alcance 1 a 3 em cruz), Duplicar, Portal | tochas soltas → fileiras com laço → pares que pedem o alcance certo; usa a runa mágica Fogo de verdade |
| Sapo | Atravesse o rio | setas (cada pulo é um tique), Duplicar, Portal | mais fileiras de troncos; no nível 5 uma corre 2 casas por tique; solução por busca em (posição, tique) |

## Polimento (madrugada de 08/11)

- Música de fundo gerada em código (dó, lá menor, fá, sol a 132 bpm), mais rápida a cada nível e no chefão; tecla M liga/desliga.
- Sons gerados em código (`scripts/ware/ware_sfx.gd`): passos, batidas, moedas em escala subindo, sinos com nota de verdade, tiro, explosão, tique do relógio nos últimos 10 s, vitória e derrota.
- O editor mostra a **foto do desafio** no canto (só a parte que importa: `content_rect()` de cada jogo); mouse em cima ou TAB amplia.
- Entre jogos a orbe cobre a tela; confete na vitória; aviso "NÍVEL N: MAIS RÁPIDO!"; coração que se quebra; cartão da ordem mostra as runas do jogo; barra de baixo mostra as runas e os limites.
- Cada jogo ganhou partículas, tremida de tela e animações (pegadas, porta abrindo, cavaleiro andando e girando ao cair, régua de passos na plataforma, recuo e fumaça do canhão, raio e estilhaços na torreta, bolhas e fumaça no caldeirão, muralha rachando).
- Intensidade só vai até 255 (1 byte): a Torreta passou a girar até 180 por runa. O teste agora confere isso e também usa a VM de verdade, que foi o que achou o problema.
- Tamanho das soluções controlado (labirintos e caixas longos demais são sorteados de novo) e o tempo ganha 3 s por runa acima de 6.
- Cenários de fundo por jogo (salão com tochas, castelo e lua, depósito, torre com vitrais, cavalete, radar, prateleiras de poções, lápides).
- Menu: o treino mostra o maior nível vencido de cada jogo (e começa nele); fim de jogo mostra a partida em cartões (verde venceu, vermelho perdeu) e festeja recorde novo.
- `tests/ware_smoke.gd` também confere que todo texto na tela existe nas fontes pixel (a fonte pequena não tem ";") e que soltar as runas da solução na linha pronta do editor vence.

## Soltar runas (pedido do usuário, 08/11)

- Antes a runa só ficava se fosse solta em cima do traço; os quadradinhos onde o ícone aparece (ao lado da linha) não aceitavam. Agora soltar dentro ou perto do quadradinho também vale, tanto vindo da paleta quanto movendo uma runa que já está na mesa.
- Enquanto arrasta, o quadradinho de destino acende, para mostrar onde a runa vai cair.
- Implementação: `snap_drops_to_slots` (desligado por padrão) e `drop_target_at()` em `atelier_canvas.gd`; a HUD pixel (`spell_creation.gd`) liga o snap. O editor livre/Sandbox continua igual.

## Revisão independente (08/11)

Um revisor separado rodou repros contra o código e achou 4 problemas, todos corrigidos e cobertos no `ware_smoke`: laço sem fim prendia a rodada (agora PARAR e o relógio volta após 6 s); runa sendo arrastada quando o tempo acabava ia parar no próximo jogo; o editor aceitava runa fora da paleta (por exemplo colada com Ctrl+V); e o HUD parava de redesenhar em algumas telas (coração perdido, dica).

Uma segunda revisão olhou Sapo, Fogueiras e o editor: o desenho do Sapo bate com a lógica em todos os tiques testados; corrigidos Fogueiras nível 3 (um Fogo 3 no meio acendia tudo sem laço: agora o Fogo só alcança 1 nos níveis 3 e 4), dígito acima do máximo, LIMPAR sem desfazer (agora Ctrl+Z volta), Fogo 0 acendendo, nomes longos cortados no painel da arena, setas do Sapo cortadas no mapa e PARAR sem repetir a melodia dos Sinos.

## Perguntas em aberto

- [ ] O cronômetro deveria parar com o editor aberto (mais calmo) ou continuar (mais WarioWare)?
- [ ] Ganhar no meio de um laço infinito está certo, ou o ritual precisa terminar?
- [ ] Os microjogos ficam como modo próprio ou viram salas/eventos dentro da arena?
