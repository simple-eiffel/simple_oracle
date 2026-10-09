# Changelog

## [Unreleased] - 2026-10-08

### Fixed
- `ORACLE_CLI` compile, test and git output is read as raw bytes (`last_output_bytes`) instead of `to_string_8` of decoded text, which fails above U+00FF with simple_process 1.1.0.
- Fixed VEEN in `dbc_heatmap_analyzer`: uses `utf_8_name` instead of `to_string_8` on PATH.
- Committed work-in-progress from 2026-09-02: changes dated 2026-02-01 onward (oracle.db excluded).
- Committed three SQL pattern files found untracked the same day.

