# Spec Delta

## Purpose

Permitir instalar, ativar, acompanhar e remover o Zonari no Omarchy pelo mecanismo de plugins do próprio Omarchy, sem `sudo` e sem quebrar uma sessão cujo Hyprland não é compatível.

## ADDED Requirements

### Requirement: Repositório aceito como plugin do Omarchy
O repositório SHALL passar em `omarchy plugin validate`: `manifest.json` na raiz com `schemaVersion` 1, id fora de `omarchy.*`, kind `bar-widget` com `entryPoints.barWidget` existente, e nenhum link simbólico rastreado.

#### Scenario: Validação
- **WHEN** `omarchy plugin validate` roda sobre uma cópia limpa dos arquivos do repositório
- **THEN** sai com 0

### Requirement: Setup só com Hyprland compatível
`zonari setup` SHALL recusar, sem gravar nada, um Hyprland em execução anterior a 0.56.2, cabeçalhos de versão diferente da versão em execução, ou ausência de `~/.config/hypr/hyprland.lua`.

#### Scenario: Hyprland antigo
- **WHEN** o setup roda com um Hyprland anterior a 0.56.2 em execução
- **THEN** sai com erro citando 0.56.2 e não cria `~/.local/share/zonari`, `zonari.lua` nem altera `hyprland.lua`

### Requirement: Árvore do plugin conforme a versão
Na 0.56.x o setup SHALL compilar `zonari-bars-0.56/`; na 0.57+ SHALL compilar `zonari-bars/`. As duas árvores SHALL registrar as mesmas funções `hl.plugin.zonari.*`, e o núcleo e a UI são os mesmos.

#### Scenario: Omarchy 4.5
- **WHEN** o setup roda com o Hyprland 0.56.2
- **THEN** compila `zonari-bars-0.56/` e `zonari status` informa `plugin_line` = `0.56`

### Requirement: Setup reversível e sem sobrescrever o usuário
Com Hyprland compatível, `zonari setup` SHALL compilar `zonari-ui` e o plugin em `~/.local/share/zonari`, gravar `~/.config/hypr/zonari.lua` por temporário + rename só se ele não existir, e manter exatamente uma linha `require("hypr.zonari")` em `hyprland.lua`, com backup do original na primeira vez. `zonari remove` SHALL devolver `hyprland.lua` ao conteúdo anterior, apagar só os arquivos que o setup criou e guardar um `zonari.lua` editado pelo usuário em vez de apagá-lo.

#### Scenario: Setup repetido
- **WHEN** o setup roda duas vezes
- **THEN** há uma só linha `require` e o backup continua sendo o original

#### Scenario: Remoção
- **WHEN** `zonari remove` roda depois do setup
- **THEN** `hyprland.lua` fica igual ao original e um `zonari-ui` que o setup não instalou continua no lugar

### Requirement: Atalhos sem conflito com o Omarchy
O `zonari.lua` gerado SHALL usar `mod = "SUPER + CTRL + SHIFT"`. O Alt+Tab do Zonari SHALL ser opcional e desligado por padrão; ligado (`setup --alt-tab`, resposta sim na pergunta do setup, ou `zonari alt-tab on`), SHALL remover o par `ALT + TAB`/`ALT + SHIFT + TAB` do Omarchy antes de registrar o do Zonari. `zonari alt-tab on|off` SHALL gravar por temporário + rename.

#### Scenario: Atalhos padrão
- **WHEN** o setup gera `zonari.lua`
- **THEN** nenhum atalho do Zonari coincide com um atalho padrão do Omarchy 4.5

### Requirement: Estado e plugin desatualizado visíveis
`zonari status --json` SHALL informar versão em execução, compatibilidade, configuração, plugin compilado, recibo de ABI igual ao do Hyprland instalado, plugin carregado e `zonari-ui` instalado; o widget da barra SHALL mostrar esse estado e oferecer setup ou rebuild por clique, sem executar nada sozinho.

#### Scenario: Hyprland atualizado
- **WHEN** o Hyprland instalado muda de commit depois do setup
- **THEN** `abi_ok` passa a `false` e o widget oferece o rebuild
