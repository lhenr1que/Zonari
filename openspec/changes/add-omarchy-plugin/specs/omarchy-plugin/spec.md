# Spec Delta

## Purpose

Permitir instalar, ativar, acompanhar e remover o HyperVi no Omarchy pelo mecanismo de plugins do próprio Omarchy, sem `sudo` e sem quebrar uma sessão cujo Hyprland não é compatível.

## ADDED Requirements

### Requirement: Repositório aceito como plugin do Omarchy
O repositório SHALL passar em `omarchy plugin validate`: `manifest.json` na raiz com `schemaVersion` 1, id fora de `omarchy.*`, kind `bar-widget` com `entryPoints.barWidget` existente, e nenhum link simbólico rastreado.

#### Scenario: Validação
- **WHEN** `omarchy plugin validate` roda sobre uma cópia limpa dos arquivos do repositório
- **THEN** sai com 0

### Requirement: Setup só com Hyprland compatível
`hypervi setup` SHALL recusar, sem gravar nada, um Hyprland em execução anterior a 0.56.2, cabeçalhos de versão diferente da versão em execução, ou ausência de `~/.config/hypr/hyprland.lua`.

#### Scenario: Hyprland antigo
- **WHEN** o setup roda com um Hyprland anterior a 0.56.2 em execução
- **THEN** sai com erro citando 0.56.2 e não cria `~/.local/share/hypervi`, `hypervi.lua` nem altera `hyprland.lua`

### Requirement: Árvore do plugin conforme a versão
Na 0.56.x o setup SHALL compilar `plugin-0.56/`; na 0.57+ SHALL compilar `plugin/`. As duas árvores SHALL registrar as mesmas funções `hl.plugin.kwinish.*`, e o núcleo e a UI são os mesmos.

#### Scenario: Omarchy 4.5
- **WHEN** o setup roda com o Hyprland 0.56.2
- **THEN** compila `plugin-0.56/` e `hypervi status` informa `plugin_line` = `0.56`

### Requirement: Setup reversível e sem sobrescrever o usuário
Com Hyprland compatível, `hypervi setup` SHALL compilar `kwinish-ui` e o plugin em `~/.local/share/hypervi`, gravar `~/.config/hypr/hypervi.lua` por temporário + rename só se ele não existir, e manter exatamente uma linha `require("hypr.hypervi")` em `hyprland.lua`, com backup do original na primeira vez. `hypervi remove` SHALL devolver `hyprland.lua` ao conteúdo anterior, apagar só os arquivos que o setup criou e guardar um `hypervi.lua` editado pelo usuário em vez de apagá-lo.

#### Scenario: Setup repetido
- **WHEN** o setup roda duas vezes
- **THEN** há uma só linha `require` e o backup continua sendo o original

#### Scenario: Remoção
- **WHEN** `hypervi remove` roda depois do setup
- **THEN** `hyprland.lua` fica igual ao original e um `kwinish-ui` que o setup não instalou continua no lugar

### Requirement: Atalhos sem conflito com o Omarchy
O `hypervi.lua` gerado SHALL usar `mod = "SUPER + CTRL + SHIFT"`. O Alt+Tab do HyperVi SHALL ser opcional e desligado por padrão; ligado (`setup --alt-tab`, resposta sim na pergunta do setup, ou `hypervi alt-tab on`), SHALL remover o par `ALT + TAB`/`ALT + SHIFT + TAB` do Omarchy antes de registrar o do HyperVi. `hypervi alt-tab on|off` SHALL gravar por temporário + rename.

#### Scenario: Atalhos padrão
- **WHEN** o setup gera `hypervi.lua`
- **THEN** nenhum atalho do HyperVi coincide com um atalho padrão do Omarchy 4.5

### Requirement: Estado e plugin desatualizado visíveis
`hypervi status --json` SHALL informar versão em execução, compatibilidade, configuração, plugin compilado, recibo de ABI igual ao do Hyprland instalado, plugin carregado e `kwinish-ui` instalado; o widget da barra SHALL mostrar esse estado e oferecer setup ou rebuild por clique, sem executar nada sozinho.

#### Scenario: Hyprland atualizado
- **WHEN** o Hyprland instalado muda de commit depois do setup
- **THEN** `abi_ok` passa a `false` e o widget oferece o rebuild
