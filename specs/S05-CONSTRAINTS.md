# S05: CONSTRAINTS - simple_oracle

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Technical Constraints

### Platform
- **OS**: Windows primary, cross-platform potential
- **Compiler**: EiffelStudio 25.02+
- **Concurrency**: SCOOP compatible

### Dependencies
- simple_sql for SQLite
- simple_time for timestamps
- Base library

### Database
- SQLite 3.x with FTS5
- WAL mode for durability
- Single writer limitation

## Design Constraints

### Dual Database Architecture
- Memory DB for fast reads
- Disk DB for persistence
- Write-through to disk
- Cache sync on startup

### FTS5 Requirements
- Knowledge table is virtual (FTS5)
- Cannot be synced to memory
- Queried directly from disk

### Single Instance
- One oracle per database file
- Multiple instances may conflict
- Close properly to avoid corruption

## API Constraints

### is_ready Check
- Most operations require is_ready
- Ensures databases are open
- Fail gracefully if not ready

### Path Requirements
- Database path non-empty
- Library paths non-empty
- Names non-empty

## Operational Constraints

### Memory Mode
- is_memory_only for testing
- No persistence
- Both DBs point to same in-memory

### Close Requirement
- Must call close before exit
- Prevents database corruption
- Flushes pending writes

## Known Limitations

1. **Single Writer**
   - SQLite limitation
   - Concurrent reads OK
   - Writes serialize

2. **Memory Sync**
   - Some tables sync to memory
   - FTS5 tables disk-only
   - Knowledge queried from disk

3. **Daemon Incomplete**
   - Real-time watching not complete
   - Manual scanning required
   - Future enhancement

4. **NL Query Limitations**
   - Basic keyword matching
   - No semantic understanding
   - Relies on FTS5
