---
tags: [testes, ferramentas]
---
# 12 — Testes e ferramentas

## Runner

`tools/run_tests.ps1` descobre todas as suítes `tests/*_smoke.gd`, roda cada uma com `godot --headless --script`, e falha se houver exit code ≠ 0, `SCRIPT ERROR:`, `Assertion failed` **ou** se a suíte não imprimir sua linha `*_OK`.

```powershell
$godot = 'C:\Users\Pichau\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& C:\godot\atelier-ide\tools\run_tests.ps1 -GodotPath $godot
& C:\godot\atelier-ide\tools\run_tests.ps1 -GodotPath $godot -Native -RitualPath C:\Users\Pichau\Downloads\fibby.atelier
```

`-Native` acrescenta `tests/nasm_all_runes.gd` e exige NASM/GCC (MSYS2 UCRT64 em `D:\msys64`, `C:\msys64` ou `ATELIER_MSYS2_ROOT`).

## Suítes relevantes para o compilador

| Suíte | Cobre |
|---|---|
| `compiler_contracts_smoke` | Catálogo, bytecode (encode/decode, rejeições), contratos entre módulos |
| `ritual_diagnostics_smoke` | Códigos de erro do frontend (`COMPILER_*`) |
| `nasm_export_smoke` | Geração NASM estática/mutável, erros de altura de pilha |
| `nasm_all_runes` (nativo) | 56 executáveis comparados com a VM, inclusive Fibonacci |
| `file_menu_smoke` | Salvar/abrir `.atelier`, checkbox Modo assembly |
| `occupied_node`, `terminal_anchor_double_click`, `panel_geometry` | Editor |

As demais suítes (`desk_*`, `inspection_*`, `spell_judge_*`, `portrait`, `pixel_desk`…) são da **loja** e saem com o rework do jogo.

## Ferramentas

- `tools/test_ritual.gd` — roda um `.atelier` pela VM e pelo gerador NASM; opcionalmente grava `.asm`.
- `tools/run_exported_asm.ps1 ritual.asm` — `nasm -f win64` + `gcc` → `.obj`/`.exe` ao lado; executa.
- `tools/bake_rune_atlas.gd` — pré-renderiza os glifos das runas no atlas (precisa rodar ao adicionar runas novas).

## Checklist ao mexer no compilador

- [ ] `run_tests.ps1` passa.
- [ ] Se tocou em VM/backends: `-Native -RitualPath fibby.atelier` passa.
- [ ] Abriu o projeto no Godot com renderização real (headless não pega bugs de cache de painel).
- [ ] Atualizou `docs/COMPILADOR.md` e as notas deste vault.
