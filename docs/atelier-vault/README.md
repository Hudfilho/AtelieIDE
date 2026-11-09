# Atelier IDE — Vault do compilador

Este vault documenta **como o desenho de runas vira código executável** no Atelier IDE. Abra esta pasta no Obsidian como um vault (`Open folder as vault`) e comece pelo canvas.

> [!tip] Por onde começar
> 1. Abra **[[Pipeline do Compilador.canvas|Pipeline do Compilador]]** — é o mapa visual de todo o caminho, do traçado ao `.exe`.
> 2. Leia [[00 Visão Geral]] para o resumo de uma página.
> 3. Cada caixa do canvas aponta para uma nota com os detalhes e o arquivo-fonte correspondente.

## Mapa das notas

| # | Nota | Arquivo no projeto |
|---|---|---|
| 00 | [[00 Visão Geral]] | `docs/COMPILADOR.md` |
| 01 | [[01 Diagrama e Arquivo .atelier]] | `scripts/core/rune_diagram.gd`, `scripts/core/atelier_ritual_file.gd` |
| 02 | [[02 Catálogo de Runas]] | `scripts/core/rune_catalog.gd` |
| 03 | [[03 Frontend — Linearização e Validação]] | `scripts/core/rune_compiler.gd` |
| 04 | [[04 Representação Intermediária (IR)]] | `scripts/core/rune_compiler.gd` |
| 05 | [[05 Bytecode RUNE v2]] | `scripts/core/rune_bytecode.gd` |
| 06 | [[06 Máquina Virtual]] | `scripts/core/rune_vm.gd` |
| 07 | [[07 Portais e Saltos]] | `scripts/core/rune_portals.gd` |
| 08 | [[08 INT_SET e INT_MOD]] | `scripts/core/rune_vm.gd`, `rune_compiler.gd` |
| 09 | [[09 Backend NASM Estático]] | `scripts/core/rune_nasm_exporter.gd` |
| 10 | [[10 Backend NASM Mutável]] | `scripts/core/rune_nasm_mutable.gd`, `rune_nasm_common.gd` |
| 11 | [[11 Execução no Editor (Play)]] | `scripts/atelier_canvas.gd` |
| 12 | [[12 Testes e Ferramentas]] | `tools/run_tests.ps1`, `tests/` |
| 13 | [[13 Limitações Conhecidas]] | — |
| 14 | [[14 Runas Mágicas — Mudanças para o Jogo]] | `scripts/arena/` |
| 15 | [[15 Atelier Ware — Microjogos]] | `scripts/ware/` |
| — | [[Glossário]] | — |

## Convenções

- Notas descrevem o **estado atual do código** na branch `codex/test-no-rune-visuals` + merge de `game-case` (novembro/2026).
- Blocos `> [!warning]` marcam regras que são fáceis de quebrar ao estender a linguagem.
- A nota 14 é intencionalmente incompleta: será preenchida quando o jogo de combate definir as runas mágicas.
