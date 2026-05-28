# Changelog

All notable changes for Knowledge Vault.

## [2.4.1] - 2026-05-28

### Added

- Added Codex marketplace support so the plugin is installable and manageable in Codex while retaining Claude Code compatibility.
- Normalized plugin IDs and install identifiers to `knowledge-vault` across marketplace and plugin manifests.
- Added Codex-specific manifest at `plugins/knowledge-vault/.codex-plugin/plugin.json`.
- Added dedicated marketplace metadata at `plugins/knowledge-vault/.claude-plugin/marketplace.json`.
- Bumped plugin metadata versions to `2.4.1`.

## [2.4.0] - 2026-05-07

### Added

- Introduced per-PDF hierarchical PageIndex tree indexing workflow.
- Preserved original source files under `originals/<slug>.<ext>` with backward-compatible upgrade support.
- Switched paper identification to bibliographic-style slugs.
- Added 4-tier retrieval path in `/knowledge-vault:query` (wiki, tree, and page extraction).

## [2.3.0] - 2026-04-23

### Changed

- Decoupled optional Sci-Hub flow from Unpaywall.
- Relaxed user confirmation requirements for source setup steps.
