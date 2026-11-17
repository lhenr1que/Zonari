# Portable source installation

Requested by the owner on 17/11/2026: publish to GitHub, standardize the repository, retain the Omarchy plugin and allow installation on other Hyprland distributions.

Keep the existing Cargo workspace and top-level zonari-core, zonari-ui, versioned bars, omarchy, resources, scripts, tests and docs directories. Add a shell source installer independent of Omarchy, fix packaging paths following the workspace migration, and document both install routes. No distro package-manager automation or compositor/session changes.
