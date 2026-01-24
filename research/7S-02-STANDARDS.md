# 7S-02: STANDARDS - simple_oracle


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Applicable Standards

### SQLite
- **Source**: SQLite Consortium
- **Version**: 3.x (via simple_sql)
- **Features**: FTS5 for full-text search
- **Usage**: Dual database (memory + disk)

### FTS5 Full-Text Search
- **Source**: SQLite extension
- **Features**: Porter stemming, unicode61 tokenization
- **Usage**: Knowledge base queries

### ISO 8601
- **Usage**: Timestamps in database
- **Format**: datetime('now') SQL function

## Database Schema

### Core Tables
- **libraries**: Registered simple_* libraries
- **events**: Activity log (compile, test, git, etc.)
- **classes**: Parsed class information
- **features**: Feature signatures and contracts
- **knowledge**: FTS5 knowledge base
- **patterns**: Design patterns reference

### Tracking Tables
- **compilations**: Build history
- **test_runs**: Test execution history
- **git_commits**: Version control history
- **session_handoff**: Context continuity

### Relationship Tables
- **class_parents**: Inheritance hierarchy
- **class_clients**: Client/supplier relationships
- **compiled_stats**: EIFGENs metadata

## Coding Standards

- Design by Contract throughout
- SCOOP compatibility
- Void safety enforced
- simple_sql for database operations

## Integration Standards

- CLI interface (oracle-cli.exe)
- Boot sequence for session start
- Handoff for session end
- Natural language query interface
