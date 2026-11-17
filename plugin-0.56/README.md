# kwinish-bars for Hyprland 0.56.x (frozen)

The title-bar plugin as it was at commit `9850593`, the last state tested live on Hyprland 0.56.2 before the 0.57 port.
`omarchy/hypervi setup` builds this tree when the running Hyprland is 0.56.x (Omarchy 4.5 ships 0.56.2) and `plugin/` on 0.57+.
The Lua core and `kwinish-ui` are shared: both trees register the same `hl.plugin.kwinish.*` functions (checked by
`tools/test-omarchy-plugin.sh`).

Not here, only in `plugin/`: the fixes made during the 0.57 port, notably `fix-input-ipc` part 1 (press and wheel only on
the bar under the pointer, button symbols per monitor scale), `849bf16` (pointer stays on the bar when a drag leaves
maximized) and `874a9df` (bar drawn from the frame's presentation snapshot). Frozen: only critical fixes, each with a test.
Delete this directory when Omarchy ships Hyprland 0.57.
