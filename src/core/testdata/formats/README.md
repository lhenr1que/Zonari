Valid files exactly as the writers make them (rules, workspace modes and columns by the core's serializers; settings and shortcuts
by serde_json::to_string_pretty in zonari-ui; layouts.json by zones::render, checked byte for byte by a Rust test). Read by
src/core/test_userdata.lua and crates/zonari-ui/src/zones.rs: the readers must keep giving these entries.
