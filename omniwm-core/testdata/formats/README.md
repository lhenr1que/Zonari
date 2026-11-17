Valid files exactly as the writers make them (rules, workspace modes and columns by the core's serializers; settings and shortcuts
by serde_json::to_string_pretty in omniwm-ui; layouts.json by zones::render, checked byte for byte by a Rust test). Read by
omniwm-core/test_userdata.lua and omniwm-ui/src/zones.rs: the readers must keep giving these entries.
