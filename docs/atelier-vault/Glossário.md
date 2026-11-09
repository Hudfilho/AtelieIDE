---
tags: [glossario]
---
# Glossário

- **Célula / conexão** — um segmento entre dois pontos da grade. Pode ter runa e intensidade.
- **Runa / selo / símbolo** — o `kind` atribuído a uma célula; mapeia para um opcode no [[02 Catálogo de Runas]].
- **Intensidade** — inteiro 0–255 da célula. Conforme a runa, é literal, endereço, id de portal ou caractere.
- **Intensidade efetiva** — o valor atual na cópia em execução, após `INT_SET`/`INT_MOD`.
- **Sequência** — componente conexo do desenho com exatamente duas pontas; vira uma lista de instruções terminada em `HALT`.
- **Ritual** — um diagrama completo (o "programa"). Arquivo `.atelier`.
- **IR** — lista linear de instruções com origem ([[04 Representação Intermediária (IR)]]).
- **RUNE** — formato de bytecode, versão 2 ([[05 Bytecode RUNE v2]]).
- **Portal** — `WARP`, `WARP END`, `JUMP_IF_TRUE` ([[07 Portais e Saltos]]).
- **Produtora** — instrução com `result_type: "int"`; alimenta `INT_SET`.
- **Oráculo** — painel de saída/erros do editor.
- **RPS** — runas por segundo, velocidade do Play.
- **Backend estático / mutável** — os dois geradores NASM ([[09 Backend NASM Estático]], [[10 Backend NASM Mutável]]).
- **Pilha mágica** — pilha separada de propriedades de feitiço, alimentada por runas mágicas ao executar ([[14 Runas Mágicas — Mudanças para o Jogo]]).
- **Cast** — momento em que a pilha mágica vira um feitiço.
- **Sandbox** — `scenes/Main.tscn`, editor livre com as 30 runas.
- **Loja / game-case** — modo de jogo antigo (balcão e encomendas), a ser removido.
