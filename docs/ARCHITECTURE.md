# Arquitetura implementada do Zonari

Referência documental de **29/10/2026**, baseada no código do commit `a2506c63dad16384414dc95919b8292aead284df`. A base de testes registrada é Hyprland **0.56.2**. Esta revisão foi estática: não executou suítes, builds, sessões aninhadas ou ações no compositor.

Este documento descreve a implementação existente. A [visão de produto](product/README.md) e o [registro D-01–D-45](product/DECISIONS.md) tratam a evolução futura; não ampliam os contratos atuais. Instalação: [README](../README.md). Interfaces e formatos: [API](API.md). Opções: [CONFIGURAVEL](CONFIGURAVEL.md). Evidências e desvios: [STATUS](STATUS.md).

## Componentes e responsabilidades

| Componente | Responsabilidade implementada | Evidência |
|---|---|---|
| Hyprland | Composição, clientes, foco, workspaces, layouts nativos e eventos | Chamadas `hl.*` em [zonari-core/zonari.lua](../zonari-core/zonari.lua) |
| Núcleo Lua | Políticas e ações de janelas, zonas, modos, regras, Alt+Tab e teclas | [zonari.lua](../zonari-core/zonari.lua), [switcher.lua](../zonari-core/switcher.lua), [binds.lua](../zonari-core/binds.lua) |
| Plugin C++ `zonari-bars` | Decoração e entrada da barra de título, prévia/zonas, drag e integração no compositor | [main.cpp](../zonari-bars/main.cpp), [barDeco.cpp](../zonari-bars/barDeco.cpp) |
| `zonari-ui` Rust/GTK4 | Overlays, menu, layouts/editor, Snap Assist, Settings, atalho e barras de reserva | [main.rs](../zonari-ui/src/main.rs), [menu.rs](../zonari-ui/src/menu.rs), [settings.rs](../zonari-ui/src/settings.rs) |
| Recipes e ferramentas | Carregamento/configuração de exemplo, desenvolvimento, testes e empacotamento | [snippet](../resources/recipes/hyprland-snippet.lua), [check.sh](../scripts/check.sh), [PKGBUILD](../resources/packaging/PKGBUILD) |

O núcleo é carregado pela configuração Lua do Hyprland. Não há daemon de políticas independente do compositor nem um motor de tiling próprio. A independência em relação a um shell visual é uma fronteira possível desta arquitetura: as políticas pertencem ao núcleo, e as superfícies pedem ações. Hoje a integração usa diretamente a API do Hyprland, sem serviço público versionado para shells.

O plugin fornece **barras de título**, não a barra de tarefas da futura suíte. A UI existente também não fornece dock, launcher de aplicativos, Overview com miniaturas ou Rice Store.

## Fluxos de comunicação atuais

```text
teclas/eventos Hyprland ──> núcleo Lua ──> dispatchers/API hl.*
                                   ├──> namespace hl.plugin.zonari
                                   └──> JSON runtime ──> views zonari-ui
barra/plugin ou view GTK ──> hyprctl eval ──> núcleo/window_action
```

- [`window_action(addr, action)`](../zonari-core/zonari.lua), linhas 372–436 do baseline, é a entrada utilizada por menus e ações encaminhadas ao núcleo. O endereço é o identificador Hyprland do cliente; não há identidade própria durável/versionada de janela.
- Plugin e UI usam `hyprctl eval` para chegar ao núcleo; o plugin também executa ações internas do compositor. Portanto, não se deve inferir que toda interação já passa por uma camada IPC abstrata única.
- O núcleo publica `switcher.json` e `assist.json` em `$XDG_RUNTIME_DIR/zonari/`. Alt+Tab mantém a lógica de teclas/foco em [switcher.lua](../zonari-core/switcher.lua); o overlay [main.rs](../zonari-ui/src/main.rs) desenha sem tomar o foco do teclado.
- Snap Assist usa publicação atômica, geração e serialização de lançamentos por `flock`; a view confere geração/existência antes de agir. Os riscos adicionais de revalidar contexto de workspace/monitor/layout continuam registrados em STATUS.
- O namespace `hl.plugin.zonari` permite publicar zonas e acionar funções do plugin. A superfície atual e seus limites estão na [API v0](API.md).

Um serviço de snapshot/eventos, handshake de versão e comandos semânticos adicionais é [proposta futura](product/PROPOSALS.md). Não existe como contrato já disponível para os shells estudados.

## Modos de workspace e geometria

[`zonari-core/modes.lua`](../zonari-core/modes.lua), `engine()` e `from_engine()`, associa Tiling a `dwindle` e Scroll (`scrolling` no código) ao layout `scrolling` nativo. Floating mantém `dwindle` subjacente e aplica flutuação às janelas do workspace.

O núcleo usa etiquetas como `zonari-mode-floated` e `zonari-rect-X-Y-W-H` para procedência e geometria. Preferências são persistidas por workspace numérico; as colunas lembradas são de 1 a 3. Um modo inicial global com exceções por monitor, conforme D-24, ainda é produto futuro.

Encaixe rápido, eixo, empacotamento e zonas calculam retângulos a partir da área útil do monitor. Layouts de zonas definidos pelo usuário ficam em `layouts.json`; eles não substituem o motor nativo de tiling. `tile:*` e `zone:*` podem receber monitor de destino por sufixo `@nome`, como descrito na API.

A cascata Floating é um requisito de [workspace-modes](../openspec/specs/workspace-modes/spec.md), mas há falha ao vivo registrada em 28/10. O simulador não reproduz esse resultado. A hipótese de divergência ao redeclarar a regra durante `window.open` não foi confirmada por esta revisão; o requisito continua vigente.

## Minimizar, mostrar desktop e manter acima

São mecanismos distintos no [`zonari-core/zonari.lua`](../zonari-core/zonari.lua):

| Mecanismo | Implementação | Limitação/validação |
|---|---|---|
| Minimizar | `window_action(..., "minimize")` move para `special:minimized`; hook `window.active` move/foca no workspace ativo | Sem evento/tag público próprio de minimização; mover pode apagar procedência Floating |
| Mostrar desktop | `show_desktop()` guarda origens num único `stashed` local e move janelas elegíveis do workspace ativo para `special:zonari_desktop`; chamada seguinte restaura | Reload do núcleo perde as origens; D-43/D-44/D-45 não implementadas |
| Manter acima/abaixo | Etiquetas e tabelas; `restack()` ajusta z-order após mudanças de foco; listas reconstruídas por tags ao carregar o núcleo | Correção `5333087` possui testes simulados registrados; resultado dirigido ao vivo permanece pendente no STATUS |

As origens de `show_desktop` não possuem gerações, journal nem reconciliação durável. A restauração de minimizadas pelo hook de foco não entrega automaticamente o [contrato futuro de restauração](product/WORKSPACES.md). Também não existe política de dock oficial implementada.

## Dados persistentes e efêmeros

- Preferências do usuário: `$XDG_CONFIG_HOME/zonari/` — regras, layouts, Settings, atalhos, modos/colunas e o nome do layout ativo.
- Estado efêmero das views: `$XDG_RUNTIME_DIR/zonari/` — JSON do switcher e do Assist.
- Estado transitório do núcleo: tabelas Lua, além de etiquetas mantidas nas janelas. A presença de tags não torna todo estado recarregável.

[`zonari-core/kwjson.lua`](../zonari-core/kwjson.lua) e os leitores Rust em [`zonari-ui/src/zones.rs`](../zonari-ui/src/zones.rs) leem JSON como dados, sem `load`. Limites: 1 MiB e 32 níveis; raiz inválida ou erro de sintaxe recusa o documento inteiro. Entradas inválidas num documento válido são tratadas conforme cada leitor. Casos compartilhados estão em [testdata](../zonari-core/testdata/formats/README.md).

A gravação valida o novo texto e usa temporário no mesmo diretório seguido de `rename`; arquivos persistentes recusados pelo leitor são preservados em `.bak` antes da substituição. Falhas são reportadas. A publicação é por arquivo, sem transação entre arquivos; uma configuração pode valer na sessão mesmo quando sua persistência falha. A [API, seção 4](API.md#4-files), define os formatos, escritores e consequências específicas. Runtime descartável não gera backup.

A mudança `harden-user-data-io` está implementada conforme código e resultados registrados, mas permanece [ativa](../openspec/changes/harden-user-data-io/tasks.md), com validação ao vivo parcial. Isso não autoriza sincronizar ou arquivar a mudança durante manutenção documental.

## Plugin, fallback e atualização do compositor

O plugin deriva do hyprbars, com licença/atribuição preservadas em [NOTICE](../zonari-bars/NOTICE) e [licença de origem](../zonari-bars/LICENSE.hyprland-plugins). É compilado contra internals do Hyprland, incluindo hook por símbolo em `zonari-bars/main.cpp`; precisa corresponder ao build do compositor.

[`zonari-ui/src/mode.rs`](../zonari-ui/src/mode.rs) distingue plugin carregado, outra barra carregada, tentativa de carga compatível, emergência e fallback. A verificação do recibo `.abi` antecede a tentativa automática do daemon; o próprio compositor também verifica ABI. Um recibo compatível não demonstra compatibilidade com mudanças funcionais de uma nova versão.

As barras de reserva são superfícies layer-shell: não participam do empilhamento como decoração de janela, precisam de acompanhamento/recorte e possuem limitações visuais. Um ensaio de emergência com `.so` vazio e recibo incompatível foi registrado em 24/10; não é um teste completo de atualização real de pacote. Receitas, comandos e demais limites estão em [PLUGIN](PLUGIN.md).

Este documento descreve o código de 29/10/2026, quando a base era o Hyprland 0.56.2. **Desde 01/11/2026 a base é o Hyprland 0.57.0** (port registrado em `docs/port-0-57/`, nas mudanças OpenSpec arquivadas e em `docs/DEVELOPMENT_STATE.md`); as seções acima não cobrem as mudanças do port. A [análise externa de 0.57](history/product-import/2026-10-28/external-originals/docs/product/engineering/HYPRLAND_0_57_COMPATIBILITY.md) de 28/10 era preliminar.

## Estado de implementação e de validação

| Área | Implementação no baseline | Evidência disponível |
|---|---|---|
| Núcleo/decoração/UI GTK | Existentes | Código e relatos de 24–28/10, com limites no STATUS |
| Testes automatizados | Executor e suítes existentes | Resultado registrado em 28/10: 11 suítes Lua, 4 de tools, 31 testes Rust e compilação do plugin; não repetido em 29/10 |
| Tooltips minimizar/maximizar/fechar | Existentes | Teste do dono em 27/10 e mudança arquivada |
| Tooltips fixar/ícone | Código existente, mudança ativa | Texto/build registrados; teste dirigido ao vivo pendente |
| Cascata Floating | Código e requisito existentes | Falha ao vivo registrada; simulador diverge |
| Ciclo de vida/reload | Guardas globais em parte dos hooks; estado local em outras partes | Riscos A2/A3/M1 da auditoria permanecem; nenhuma correção feita nesta revisão |
| Suite shell/Overview/Rice Store | Não implementados | Decisões e propostas de produto; sem validação de implementação |

A [auditoria técnica de 28/10](history/product-import/2026-10-28/external-originals/docs/product/engineering/AUDITORIA_CODEX_ORIGINAL_2026-10-28.txt) continua fonte datada de riscos. OpenSpec possui quatro specs principais e duas mudanças ativas; o seu estado não foi alterado por esta consolidação. Divergência entre requisito e código/teste deve continuar visível, com correção técnica futura pelo workflow próprio.
