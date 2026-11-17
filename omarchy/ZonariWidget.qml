import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Zonari in the Omarchy bar (OpenSpec add-omarchy-plugin). Reads `zonari status --json` every 15 s and on click.
// Left click: settings when Zonari is ready, otherwise setup (or rebuild after a Hyprland update) in a terminal.
// Right click: layout picker. Middle click: refresh. Nothing runs by itself: every change is a click.
BarWidget {
  id: root
  moduleName: "zonari"

  readonly property string cli: decodeURIComponent(Qt.resolvedUrl("zonari").toString().replace(/^file:\/\//, ""))
  property var info: ({})
  property bool known: false

  // ready: everything works; rebuild: plugin built for another Hyprland; setup: not installed; waiting: Hyprland < 0.57
  readonly property string mode: !known ? "unknown"
    : !info.compatible ? "waiting"
    : !(info.configured && info.ui_installed && info.plugin_built) ? "setup"
    : !info.abi_ok ? "rebuild"
    : "ready"

  readonly property string tip: {
    if (mode === "waiting") return "Zonari: needs Hyprland " + (info.required || "0.57") + ", running " + (info.hyprland || "?")
    if (mode === "setup") return "Zonari: not set up — click to run setup"
    if (mode === "rebuild") return "Zonari: Hyprland changed — click to rebuild the title bars"
    if (mode === "ready") return "Zonari " + (info.plugin_loaded ? "active" : "set up (reload Hyprland to load the title bars)")
      + " — click: settings, right click: layouts"
    return "Zonari: reading state…"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { if (!statusProc.running) statusProc.running = true }
  function inTerminal(args) {
    bar.run("omarchy-launch-floating-terminal-with-presentation " + Util.shellQuote(root.cli) + " " + args)
  }

  Process {
    id: statusProc
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.info = JSON.parse(String(text || "{}")); root.known = true } catch (e) { root.known = false }
      }
    }
  }

  Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰖲"
    active: root.mode === "setup" || root.mode === "rebuild"
    tooltipText: root.tip
    onPressed: function(b) {
      if (b === Qt.MiddleButton) { root.refresh(); return }
      if (b === Qt.RightButton) { if (root.mode === "ready") root.bar.run("zonari-ui layouts"); return }
      if (root.mode === "ready") root.bar.run("zonari-ui settings")
      else if (root.mode === "setup") root.inTerminal("setup")
      else if (root.mode === "rebuild") root.inTerminal("rebuild")
      root.refresh()
    }
  }
}
