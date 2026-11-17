# Tasks

## 1. Hyprland 0.57.2

- [x] 1.1 Diff `v0.57.0..v0.57.2` contra os cabeçalhos incluídos por `zonari-bars/` e as APIs Lua usadas por `zonari-core/`: só `CWindow::markUrgent` e `CLayerSurface::isHiddenByFullscreen` (métodos novos, não virtuais); `window.destroy` passa a entregar uma referência expirada em vez de `nil` (o núcleo não escuta `window.destroy`).
- [x] 1.2 Compilar o plugin contra os cabeçalhos do pacote Arch `hyprland 0.57.2-1` (extraídos num temporário, sem instalar): GCC 0 erros, 7 avisos (`docs/omarchy-plugin/evidence/build-gcc-0.57.2.txt`). Clang não instalado nesta máquina.
- [x] 1.3 `scripts/check.sh` com `PKG_CONFIG_PATH` apontando para esses cabeçalhos: tudo passa menos `test-plugin-hostdrag.sh`, que falha só por falta de `clang++` (`docs/omarchy-plugin/evidence/check-0.57.2.txt`).

## 2. Plugin do Omarchy

- [x] 2.1 `tests/test-omarchy-plugin.sh` vermelho antes (`docs/omarchy-plugin/evidence/red.txt`: 4 falhas).
- [x] 2.2 `manifest.json`, `omarchy/zonari`, `omarchy/ZonariWidget.qml`, `PKGBUILD`s com `hyprland>=0.57`, link de `scripts/spikes/verify` trocado por nota. Verde (`green.txt`), inclusive o `omarchy-plugin-validate` real do Omarchy 4.5.
- [x] 2.3 Controles de mutação no CLI: 4/4 mortas (mínimo 0.56, remove sem tirar a linha, mod `SUPER`, backup ausente).
- [x] 2.4 `qmllint` pegou o widget chamado `BarWidget.qml` (sombreava o tipo `qs.Ui.BarWidget`) e a propriedade `state` (colide com `Item.state`); corrigidos, com checagem no teste.

## 2b. Hyprland 0.56.2 e Alt+Tab opcional (pedido do dono, 16/11/2026)

- [x] 2b.1 Medido: núcleo atual carrega no `Hyprland --verify-config` 0.56.2 (`config ok`); a API `hl.plugin.zonari.*` é idêntica entre `9850593` e a atual; `9850593:plugin` compila contra os cabeçalhos 0.56.2 (0 erros).
- [x] 2b.2 Teste vermelho (`red-056-alttab.txt`, 16 falhas) → `zonari-bars-0.56/`, CLI (árvore por versão, `--alt-tab`, `alt-tab on|off`, pergunta com `gum`), verde (`green-056-alttab.txt`, 50 ok). Mutações 5/5 (uma sobreviveu antes: `setup --alt-tab` com `zonari.lua` existente; caso acrescentado).
- [x] 2b.3 Integração real nesta máquina num HOME temporário: `zonari setup --alt-tab` com `hyprctl`, `cargo` e `make` reais (Hyprland 0.56.2) → `status` compatível, `abi_ok`; `Hyprland --verify-config` da config gerada: `config ok`; `remove` devolve `hyprland.lua` idêntico (`integration-0.56.2-setup.log`).
- [x] 2b.4 `check.sh` nos cabeçalhos 0.56.2: tudo passou (`check-0.56.2.txt`). Nos 0.57.2: só falta `clang++` nesta máquina.

## 3. Ao vivo (dono; já possível na 0.56.2)

- [x] 2c.1 Ao vivo achou dois defeitos (corrigidos com teste vermelho antes): `zonari-bars.so` vazio (mktemp antes do make: alvo "atualizado"; `red-empty-so.txt` → `green-empty-so.txt`) e nenhuma barra do Zonari com as titlebars do Omarchy carregadas (o zonari-bars cedia a qualquer `Hyprbar`; `red-hyprbars.txt` → `green-hyprbars.txt`, 58 ok). `verify-config` da config do Omarchy dá SIGSEGV mesmo sem o Zonari (não usar como verificação).
- [~] 3.1 Ao vivo pelo agente, com aprovação do dono (16/11/2026, Hyprland 0.56.2, Omarchy 4.5): `omarchy plugin add` do clone local, widget 󰖲 na barra, `zonari setup --alt-tab`, `hyprctl reload`, plugin carregado, sem erros de config, barra do Zonari única na janela (captura), par `ALT + TAB` do Omarchy substituído, `zonari-ui` iniciado. Falta o dono: atalhos `SUPER + CTRL + SHIFT`, Alt+Tab, menu `ALT + F3`, arrasto pela barra, cliques do widget, novo login.
- [ ] 3.2 `zonari remove` e `omarchy plugin remove zonari` deixam a sessão como antes.
- [ ] 3.3 Arquivar a mudança e criar `openspec/specs/omarchy-plugin/spec.md`.
