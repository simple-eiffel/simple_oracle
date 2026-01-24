# S04: FEATURE SPECIFICATIONS - simple_oracle

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## SIMPLE_ORACLE Features

### Access Features
| Feature | Type | Description |
|---------|------|-------------|
| db_path | Query | Path to database file |
| memory_db | Query | In-memory database |
| disk_db | Query | Persistent database |
| last_error | Query | Last error message |
| is_memory_only | Query | Memory-only mode? |

### Status Features
| Feature | Type | Description |
|---------|------|-------------|
| is_ready | Query | Ready for queries? |
| has_error | Query | Last operation failed? |

### Library Registry
| Feature | Type | Description |
|---------|------|-------------|
| register_library | Command | Register library |
| library_count | Query | Number of libraries |
| all_libraries | Query | List all libraries |

### Event Logging
| Feature | Type | Description |
|---------|------|-------------|
| log_event | Command | Log an event |
| recent_events | Query | Events from last N hours |

### Natural Language Query
| Feature | Type | Description |
|---------|------|-------------|
| query | Query | NL query combining FTS + API |
| fts_search | Query | Full-text search |
| api_search | Query | Class/feature search |

### Knowledge Base
| Feature | Type | Description |
|---------|------|-------------|
| add_knowledge | Command | Add knowledge entry |
| ingest_directory | Command | Batch ingest markdown |
| knowledge_count | Query | Number of entries |
| clear_knowledge | Command | Clear all knowledge |
| category_from_path | Query | Determine category |

### Expertise Injection
| Feature | Type | Description |
|---------|------|-------------|
| inject_expertise | Query | Return expertise packet |
| is_first_boot | Query | First access this session? |
| mark_expertise_injected | Command | Mark as injected |
| full_boot | Query | Complete boot sequence |

### Context Briefing
| Feature | Type | Description |
|---------|------|-------------|
| context_brief | Query | Current state summary |

### Compilation Logging
| Feature | Type | Description |
|---------|------|-------------|
| log_compile | Command | Log compile result |
| recent_compiles | Query | Recent compilations |
| compile_stats | Query | Statistics per library |

### Test Tracking
| Feature | Type | Description |
|---------|------|-------------|
| log_test_run | Command | Log test run |
| recent_test_runs | Query | Recent test runs |
| test_stats | Query | Test statistics |
| failing_libraries | Query | Libraries with failures |

### Git Tracking
| Feature | Type | Description |
|---------|------|-------------|
| log_git_commit | Command | Log commit |
| recent_commits | Query | Recent commits |
| library_commits | Query | Commits per library |
| git_stats | Query | Git statistics |

### Session Handoff
| Feature | Type | Description |
|---------|------|-------------|
| record_handoff | Command | Record session end |
| last_handoff | Query | Get last handoff |
| handoff_brief | Query | Format as string |

### Ecosystem Statistics
| Feature | Type | Description |
|---------|------|-------------|
| ecosystem_stats | Query | Generate metrics report |
| store_compiled_stats | Command | Store EIFGENs stats |
| get_compiled_stats | Query | Retrieve stats |
| ecosystem_census | Query | Comprehensive census |

### Proactive Guidance
| Feature | Type | Description |
|---------|------|-------------|
| check_guidance | Query | Return all guidance |
| rules_summary | Query | Rules from knowledge |
| gotchas_summary | Query | Common mistakes |
| recent_errors_summary | Query | Recent errors |

### Cleanup
| Feature | Type | Description |
|---------|------|-------------|
| close | Command | Close connections |
| sync_to_disk | Command | Sync memory to disk |
| sync_memory_from_disk | Command | Load disk to memory |
