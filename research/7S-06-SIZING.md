# 7S-06: SIZING - simple_oracle

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Codebase Metrics

### Source Files
- **Total Classes**: 10
- **Main Source**: 8 classes in src/
- **Testing**: 2 classes in testing/

### Lines of Code
- SIMPLE_ORACLE: ~2200 LOC
- ORACLE_CLI: ~500 LOC
- ORACLE_ECOSYSTEM_SCANNER: ~400 LOC
- SOURCE_STATS_PARSER: ~300 LOC
- DBC_HEATMAP_ANALYZER: ~200 LOC
- ORACLE_DAEMON: ~200 LOC
- ORACLE_WATCHER_WORKER: ~150 LOC
- ORACLE_PROCESS_MONITOR: ~150 LOC
- **Total**: ~4100 LOC

### Complexity Assessment

| Component | Complexity | Rationale |
|-----------|------------|-----------|
| SIMPLE_ORACLE | High | Many features, SQL, FTS5 |
| ORACLE_CLI | Medium | Command parsing, dispatch |
| ORACLE_ECOSYSTEM_SCANNER | Medium | File system traversal |
| Other components | Low | Focused functionality |

## Performance Characteristics

### Memory Usage
- Memory DB: ~5-20MB depending on activity
- Disk DB: ~10-50MB depending on history
- In-memory for fast queries

### Query Performance
- FTS5 queries: < 50ms typical
- API search: < 100ms typical
- Event logging: < 10ms

### Database Size
- Libraries table: Small (< 100 rows)
- Events: Grows over time (thousands)
- Knowledge: Depends on ingestion

## Build Metrics

- Compile time: ~10 seconds
- Test suite: ~15 tests
- Dependencies: simple_sql, simple_time

## Storage Growth

| Data Type | Growth Rate | Retention |
|-----------|-------------|-----------|
| Events | ~100/day | Keep all |
| Compiles | ~50/day | Keep all |
| Tests | ~30/day | Keep all |
| Git commits | ~10/day | Keep all |
