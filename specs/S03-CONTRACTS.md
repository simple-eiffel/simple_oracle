# S03: CONTRACTS - simple_oracle

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## SIMPLE_ORACLE Contracts

### make_with_path (a_db_path: READABLE_STRING_GENERAL)
```eiffel
require
  path_not_empty: not a_db_path.is_empty
ensure
  is_ready: is_ready
```

### make_memory_only
```eiffel
ensure
  is_ready: is_ready
  memory_only: is_memory_only
```

## Library Registry Contracts

### register_library (a_name, a_path: READABLE_STRING_GENERAL)
```eiffel
require
  is_ready: is_ready
  name_not_empty: not a_name.is_empty
  path_not_empty: not a_path.is_empty
```

### library_count: INTEGER
```eiffel
require
  is_ready: is_ready
```

### all_libraries: ARRAYED_LIST [...]
```eiffel
require
  is_ready: is_ready
```

## Event Logging Contracts

### log_event (a_type, a_library, a_details: READABLE_STRING_GENERAL)
```eiffel
require
  is_ready: is_ready
  type_not_empty: not a_type.is_empty
```

### recent_events (a_hours: INTEGER): ARRAYED_LIST [...]
```eiffel
require
  is_ready: is_ready
  positive_hours: a_hours > 0
```

## Query Contracts

### query (a_question: READABLE_STRING_GENERAL): STRING_32
```eiffel
require
  is_ready: is_ready
  question_not_empty: not a_question.is_empty
```

### fts_search (a_terms: READABLE_STRING_GENERAL): STRING_32
```eiffel
require
  is_ready: is_ready
```

### api_search (a_terms: READABLE_STRING_GENERAL): STRING_32
```eiffel
require
  is_ready: is_ready
```

## Knowledge Base Contracts

### add_knowledge (a_category, a_title, a_content: READABLE_STRING_GENERAL)
```eiffel
require
  is_ready: is_ready
  category_not_empty: not a_category.is_empty
  title_not_empty: not a_title.is_empty
```

### ingest_directory (a_path: READABLE_STRING_GENERAL)
```eiffel
require
  is_ready: is_ready
  path_not_empty: not a_path.is_empty
```

### category_from_path (a_path: STRING_32): STRING_32
```eiffel
ensure
  result_not_empty: not Result.is_empty
```

## Session Handoff Contracts

### record_handoff (...)
```eiffel
require
  is_ready: is_ready
```

### full_boot: STRING_32
```eiffel
require
  is_ready: is_ready
ensure
  expertise_marked: expertise_injected
```

## Cleanup Contracts

### close
```eiffel
ensure
  memory_closed: memory_db = Void
  disk_closed: disk_db = Void
```

## Class Invariant

```eiffel
invariant
  db_path_not_empty: not db_path.is_empty
```
