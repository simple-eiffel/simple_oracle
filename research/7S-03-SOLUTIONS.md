# 7S-03: SOLUTIONS - simple_oracle


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Alternative Solutions Evaluated

### 1. File-Based Memory
- **Approach**: JSON/YAML files for state
- **Pros**: Simple, portable
- **Cons**: No query capability, slow search
- **Decision**: Rejected - need FTS

### 2. External Database (PostgreSQL)
- **Approach**: Full RDBMS
- **Pros**: Powerful, scalable
- **Cons**: External dependency, setup complexity
- **Decision**: Rejected - SQLite sufficient

### 3. In-Memory Only
- **Approach**: Volatile storage
- **Pros**: Fast
- **Cons**: Lost on restart
- **Decision**: Hybrid - memory cache + disk persistence

### 4. SQLite with FTS5 (Chosen)
- **Approach**: Embedded database with full-text search
- **Pros**: Fast, embedded, FTS5 for natural language
- **Cons**: Single-writer limitation
- **Decision**: Implemented

## Architecture Decisions

### Dual Database
- **memory_db**: In-memory for fast queries
- **disk_db**: Persistent for durability
- **Sync**: Write-through to disk, cache in memory

### FTS5 Knowledge Base
- **Purpose**: Natural language query support
- **Tokenization**: Porter stemmer + unicode61
- **Ranking**: BM25 relevance scoring

### Boot Sequence
- Single command: `oracle-cli.exe boot`
- Injects expertise + context + last handoff
- Instant context restoration

### Session Handoff
- Captures: current task, WIP, next steps, blockers
- Persists across sessions
- Shown on next boot

## Technology Stack

- Eiffel with simple_sql
- SQLite 3.x with FTS5
- CLI via inline C for arguments
