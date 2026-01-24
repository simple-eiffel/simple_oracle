# S06: BOUNDARIES - simple_oracle

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## System Boundaries

```
+------------------+               +------------------+
|   Claude Code    | <----------> |   oracle-cli     |
|   Session        |   Commands   |                  |
+------------------+               +------------------+
                                          |
                                          v
                                   +------------------+
                                   |   SIMPLE_ORACLE  |
                                   |   - Events       |
                                   |   - Knowledge    |
                                   |   - Handoffs     |
                                   +------------------+
                                      |           |
                         +------------+           +------------+
                         |                                     |
                         v                                     v
                  +---------------+                    +---------------+
                  |  memory_db    |                    |   disk_db     |
                  |  (fast cache) |                    |   (oracle.db) |
                  +---------------+                    +---------------+
                                                              |
                                                              v
                                                       +---------------+
                                                       |  File System  |
                                                       |  - .e files   |
                                                       |  - .md files  |
                                                       |  - EIFGENs    |
                                                       +---------------+
```

## External Interfaces

### Input Boundaries

| Interface | Format | Source |
|-----------|--------|--------|
| CLI commands | String args | User/Claude |
| Event data | Tuples | Library/CLI |
| Knowledge files | Markdown | File system |
| Source files | Eiffel | File system |

### Output Boundaries

| Interface | Format | Destination |
|-----------|--------|-------------|
| Query results | String | CLI/stdout |
| Boot packet | String | Claude context |
| Statistics | Formatted text | User/Claude |
| Errors | String | stderr |

## Database Schema Boundary

### Core Tables
- libraries, events, classes, features

### Tracking Tables
- compilations, test_runs, git_commits

### Session Tables
- session_handoff

### Derived Tables
- class_parents, class_clients, compiled_stats

### Virtual Tables (FTS5)
- knowledge

## Trust Boundaries

### Trusted
- simple_sql (validated queries)
- File system (user permissions)
- CLI arguments (local user)

### Untrusted
- File contents (may be malformed)
- User queries (sanitized by FTS5)

## Versioning

- Library version: 1.0
- Schema version: 1
- Database: SQLite 3.x
