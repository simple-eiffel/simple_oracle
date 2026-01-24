# S01: PROJECT INVENTORY - simple_oracle

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Project Structure

```
simple_oracle/
  src/
    simple_oracle.e            # Core oracle class
    oracle_cli.e               # Command-line interface
    oracle_ecosystem_scanner.e # Library/class scanning
    source_stats_parser.e      # Source file statistics
    dbc_heatmap_analyzer.e     # Contract coverage analysis
    oracle_daemon.e            # Background watcher
    oracle_watcher_worker.e    # File change worker
    oracle_process_monitor.e   # Process monitoring
  testing/
    test_app.e                 # Test application entry
    lib_tests.e                # Test suite
  research/                    # 7S research documents
  specs/                       # Specification documents
  simple_oracle.ecf            # Library ECF configuration
  oracle.db                    # SQLite database (runtime)
```

## File Counts

| Category | Count |
|----------|-------|
| Source (.e) | 10 |
| Configuration (.ecf) | 1 |
| Documentation (.md) | 15+ |
| Database | 1 (runtime) |

## Dependencies

### simple_* Ecosystem
- simple_sql (SQLite access)
- simple_time (timestamps)

### ISE Libraries
- base
- time

## Build Targets

| Target | Type | Purpose |
|--------|------|---------|
| simple_oracle | library | Reusable library |
| oracle-cli | executable | CLI tool |
| simple_oracle_tests | executable | Test suite |

## Version

Current: 1.0
