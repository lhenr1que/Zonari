# Proposal

## Why

O dono quer o OmniWM no Hyprland mais recente e instalável como plugin do Omarchy (pedido de 16/11/2026). O Omarchy 4.5 instala plugins de shell com `omarchy plugin add <git-url>`: clona o repositório em `~/.config/omarchy/plugins/<id>`, valida `manifest.json` e recusa qualquer link simbólico. O OmniWM não tinha manifesto, tinha um link rastreado (`scripts/spikes/verify/.local/share/omniwm/core`, apontando para um caminho de outra máquina) e exigia instalação manual em três passos.

Decisão do dono (16/11/2026): **empacotar primeiro** (plugin do tipo `bar-widget` que instala e ativa o OmniWM atual); portar a UI para overlays do shell Omarchy fica para depois. Alvo: **Hyprland 0.57.2**. Pedido seguinte do dono (16/11/2026): **suportar também a 0.56.2** (Omarchy 4.5) e **oferecer o Alt+Tab do OmniWM no lugar do Omarchy, como opção**.

## What Changes

- `manifest.json` na raiz: id `omniwm`, kind `bar-widget`, entrada `omarchy/OmniWMWidget.qml`.
- `omarchy/omniwm` (bash): `status [--json]`, `setup`, `rebuild`, `remove`. `setup` recusa Hyprland < 0.56.2 ou cabeçalhos diferentes do compositor em execução; na 0.56.x compila `omniwm-bars-0.56/` (cópia congelada de `9850593:plugin`, a última testada ao vivo na 0.56.2, mesma API `hl.plugin.omniwm.*`), na 0.57+ compila `omniwm-bars/`; compila `omniwm-ui` e o plugin em `~/.local/share/omniwm`; grava `~/.config/hypr/omniwm.lua` (temporário + rename, nunca sobrescreve) e acrescenta uma linha `require("hypr.omniwm")` ao `hyprland.lua`, com backup. `remove` desfaz tudo.
- Atalhos no Omarchy com `mod = "SUPER + CTRL + SHIFT"` (nenhum atalho padrão do Omarchy 4.5 usa; `SUPER` colide em 8 e `SUPER + ALT` é do Omarchy). Alt+Tab do OmniWM opcional: o setup pergunta (padrão não), `setup --alt-tab` ou `omniwm alt-tab on|off`; ligado, remove o par `ALT + TAB`/`ALT + SHIFT + TAB` do Omarchy com `hl.unbind`.
- Widget da barra: estado (aguardando 0.57, falta setup, falta rebuild, pronto) e cliques para setup/rebuild num terminal, configurações e seletor de layouts.
- `scripts/check.sh` compila `omniwm-bars-0.56/` quando os cabeçalhos são 0.56.x; `test-plugin-hostdrag.sh` pula a compilação de `hostDrag.hpp` (só existe na árvore 0.57) com cabeçalhos 0.56.
- `resources/packaging/PKGBUILD` e `resources/packaging/bars/PKGBUILD` passam a depender de `hyprland>=0.57`.
- Remove o link simbólico pendente de `scripts/spikes/verify` (substituído por uma nota com o alvo original e como recriar).

## Capabilities

### New Capabilities
- `omarchy-plugin`: instalação, ativação, estado e remoção do OmniWM como plugin do Omarchy.

### Modified Capabilities

Nenhuma. Núcleo, UI e plugin C++ não mudam.

## Impact

Arquivos novos: `manifest.json`, `omarchy/omniwm`, `omarchy/OmniWMWidget.qml`, `tests/test-omarchy-plugin.sh`. Alterados: os dois `PKGBUILD`, `README.md`, `docs/STATUS.md`, `docs/DEVELOPMENT_STATE.md`. Removido: o link de `scripts/spikes/verify`.

Hyprland 0.57.0 → 0.57.2: o plugin compila sem mudança contra os cabeçalhos do pacote Arch `hyprland 0.57.2-1` (GCC, 0 erros, 7 avisos, iguais aos de antes); os cabeçalhos usados mudaram só por dois métodos não virtuais novos (`CWindow::markUrgent`, `CLayerSurface::isHiddenByFullscreen`). Recompilar continua obrigatório (o Hyprland confere o commit).
