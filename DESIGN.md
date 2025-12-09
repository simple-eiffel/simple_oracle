# SIMPLE_ORACLE Design Document

## Vision

**simple_oracle** is Claude's external memory and development intelligence platform. It solves the fundamental problem of context compression by externalizing state to a persistent, queryable system that survives across sessions.

## Core Principle

> "My forgetting is irrelevant because I don't need to remember - I just ask the oracle."

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLAUDE CODE                               │
│  ┌─────────────┐                                                │
│  │ CLAUDE.md   │ ──────> Boot instructions                      │
│  │ (bootloader)│         "Run oracle-cli boot"                  │
│  └─────────────┘                                                │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ORACLE CLI                                  │
│  oracle-cli boot | query | log | status | scan                  │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SIMPLE_ORACLE                                │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │   Memory DB      │    │    Disk DB       │                   │
│  │   (SQLite)       │◄──►│   (oracle.db)    │                   │
│  │   Fast queries   │    │   Persistent     │                   │
│  └──────────────────┘    └──────────────────┘                   │
│           │                                                      │
│           ▼                                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  FTS5 Full-Text Search Engine                             │   │
│  │  Natural language → SQL → Results                         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ORACLE DAEMON (optional)                      │
│  - File watcher (simple_watcher)                                │
│  - Process monitor (ec.exe, tests)                              │
│  - Git hook integration                                         │
└─────────────────────────────────────────────────────────────────┘
```

## Feature Modules

### 1. Expertise Injection
**Purpose:** Transform generic Claude into Larry's Eiffel expert on boot.

- Token-efficient knowledge packet (~400 tokens)
- Eiffel language core, DBC patterns, simple_* conventions
- Oracle command reference
- Called once per session via `full_boot`

**Files:** Built into SIMPLE_ORACLE class

---

### 2. Activity Monitor
**Purpose:** Track all development activity in real-time.

Events tracked:
- File changes (*.e, *.ecf created/modified/deleted)
- Compilations (ec.exe invocations, success/failure)
- Test runs (which tests, pass/fail)
- Git operations (commits, pushes, branch changes)
- Errors and exceptions

**Tables:** `events`
**Libraries needed:** simple_watcher, simple_process

---

### 3. Knowledge Base
**Purpose:** Indexed, searchable repository of all ecosystem knowledge.

Content types:
- Reference documentation (parsed from ref_docs)
- API documentation (from EiffelStudio -short output)
- Design decisions and rationale
- How-to guides and examples

**Tables:** `knowledge` (FTS5 virtual table)
**Libraries needed:** simple_file, simple_json

---

### 4. API Registry
**Purpose:** Index every class, feature, and contract in the ecosystem.

Indexed elements:
- Classes (name, inheritance, description)
- Features (queries, commands, signatures)
- Contracts (preconditions, postconditions, invariants)
- Exports (visibility)

**Tables:** `classes`, `features`, `contracts`
**Libraries needed:** Eiffel parser (future) or ec.exe -short output

---

### 5. Dependency Graph
**Purpose:** Track inter-library dependencies.

Data points:
- Which library uses which libraries
- ECF library references
- Class inheritance across libraries
- Feature call graph (advanced)

**Tables:** `dependencies`
**Libraries needed:** simple_xml (ECF parsing)

---

### 6. Test Oracle
**Purpose:** Track test history and identify patterns.

Data points:
- Test execution history (timestamp, duration, result)
- Pass/fail trends per test
- Flaky test detection (passes sometimes, fails sometimes)
- Coverage data (if available)

**Tables:** `test_runs`, `test_results`
**Libraries needed:** Test output parsing

---

### 7. Design Memory
**Purpose:** Remember WHY decisions were made, not just what.

Entries:
- Design decisions with rationale
- Rejected alternatives and why
- Trade-offs considered
- Links to related code/commits

**Tables:** `design_decisions`
**Libraries needed:** simple_json

---

### 8. Task Continuity
**Purpose:** Track work-in-progress across sessions.

Data points:
- Current tasks and status
- Blocked items and blockers
- Next steps planned
- Session handoff notes

**Tables:** `tasks`
**Libraries needed:** None additional

---

### 9. Pattern Library
**Purpose:** Indexed, searchable collection of reusable patterns.

Pattern types:
- Eiffel idioms
- simple_* conventions
- DBC patterns
- Win32 inline C patterns
- Error handling patterns

**Tables:** `patterns`
**Libraries needed:** None additional

---

### 10. Contract Index
**Purpose:** Searchable index of all contracts in ecosystem.

Indexed:
- Preconditions (require clauses)
- Postconditions (ensure clauses)
- Class invariants
- Loop variants/invariants

**Tables:** `contracts`
**Libraries needed:** Eiffel parser

---

### 11. Compilation History
**Purpose:** Track build patterns and failures.

Data points:
- Build timestamp, duration, result
- Error messages and locations
- Common error patterns
- Build time trends

**Tables:** `compilations`, `compile_errors`
**Libraries needed:** simple_process, output parsing

---

### 12. Cross-Library Analysis
**Purpose:** Ecosystem health dashboard.

Metrics:
- Libraries with/without tests
- Libraries with/without docs
- Phase compliance status
- Code quality indicators

**Tables:** `library_status`
**Libraries needed:** Derived from other tables

---

### 13. Productivity Metrics
**Purpose:** Real tracked productivity data.

Metrics:
- Lines of code added/modified/deleted
- Features implemented
- Tests written
- Time spent per library
- Commit frequency

**Tables:** `metrics`
**Libraries needed:** git integration, file analysis

---

## Communication Protocol

**Primary:** CLI-based (simplest, most reliable)
```bash
oracle-cli boot              # Expertise + context injection
oracle-cli query "question"  # Natural language query
oracle-cli log type lib msg  # Log an event
oracle-cli status            # Ecosystem health
oracle-cli scan              # Rescan filesystem
```

**Secondary (future):** Named pipes via simple_ipc for real-time daemon communication

---

## Database Schema Summary

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| libraries | Library registry | name, path, phase, has_tests, has_docs |
| classes | Class index | library_id, name, file_path, feature_count |
| features | Feature index | class_id, name, signature, is_query |
| contracts | Contract index | feature_id, type, expression |
| events | Activity log | event_type, library, details, timestamp |
| knowledge | Knowledge base (FTS5) | category, title, content |
| patterns | Pattern library | name, category, description, code_example |
| tasks | Work items | title, description, status, priority |
| test_runs | Test history | library, timestamp, passed, failed |
| compilations | Build history | library, timestamp, success, duration |
| dependencies | Dependency graph | from_library, to_library |
| design_decisions | Design rationale | title, decision, rationale, alternatives |
| metrics | Productivity data | date, library, loc_added, features_added |

---

## Dependencies (simple_* libraries)

| Library | Purpose |
|---------|---------|
| **simple_sql** | SQLite database, FTS5 |
| **simple_cli** | Command-line parsing |
| **simple_json** | JSON output formatting |
| **simple_file** | File operations |
| **simple_watcher** | File system monitoring |
| **simple_process** | Process execution/monitoring |
| **simple_xml** | ECF parsing |
| **simple_ipc** | Inter-process communication (daemon) |
| **simple_logger** | Logging |
| **simple_config** | Configuration |

---

## Implementation Phases

### Phase 1: Core (MVP)
- [x] SIMPLE_ORACLE main class
- [x] Database schema
- [x] Expertise injection
- [x] CLI interface (boot, query, log, status)
- [x] Library registry
- [x] Event logging
- [x] Context briefing

### Phase 2: Monitoring ✅ COMPLETE
- [x] File watcher integration (SCOOP daemon)
- [x] Compilation monitoring (oracle-cli compile)
- [x] Test run tracking (oracle-cli test/tests)
- [x] Git integration (oracle-cli git/commits)

### Phase 3: Knowledge
- [ ] Reference doc import
- [ ] API documentation parsing
- [ ] Full-text search tuning
- [ ] Natural language query improvement

### Phase 4: Analysis
- [ ] Dependency graph
- [ ] Cross-library analysis
- [ ] Productivity metrics
- [ ] Health dashboard

### Phase 5: Advanced
- [ ] Pattern library
- [ ] Contract indexing
- [ ] Design decision tracking
- [ ] Daemon mode with IPC

---

## Knowledge Evolution & Deprecation

Knowledge changes over time. Reference docs represent a point-in-time snapshot. Active learnings (via `learn` command) become operational knowledge while reference docs become historical context.

### Deprecation Mechanism

```sql
-- Add columns to track knowledge evolution
ALTER TABLE knowledge ADD COLUMN deprecated_at DATETIME;
ALTER TABLE knowledge ADD COLUMN deprecated_by INTEGER; -- rowid of superseding entry
ALTER TABLE knowledge ADD COLUMN deprecation_reason TEXT;
```

### Commands

```bash
# Mark knowledge as deprecated
oracle-cli deprecate <rowid> <reason>

# Supersede old knowledge with new
oracle-cli supersede <old_rowid> <category> <title> <content>

# Show history of a knowledge entry
oracle-cli history <rowid>
```

### Query Behavior

- **Default queries** exclude deprecated entries
- **Explicit `--all` flag** includes deprecated entries
- **Deprecated entries** show warning when accessed directly

---

## CLI Commands Reference

| Command | Description |
|---------|-------------|
| `boot` | Full boot sequence - inject expertise + context |
| `query <question>` | FTS5 natural language search |
| `log <type> [lib] <details>` | Log an event |
| `status` | Ecosystem health check |
| `scan` | Rescan filesystem for libraries |
| `ingest [path]` | Ingest markdown docs into knowledge base |
| `learn <cat> <title> <content>` | Add a learning |
| `deprecate <rowid> <reason>` | Mark knowledge as deprecated |
| `supersede <old_rowid> <cat> <title> <content>` | Replace old with new |
| `help` | Show help |

---

## Minimalist Metrics Philosophy

**Core Principle:** Capture only what's slow/painful to get elsewhere.

GitHub API queries take forever. Running `ec.exe -short` for every class is slow. Parsing git logs repeatedly is wasteful. The Oracle caches this expensive data locally for instant access.

### What We Capture (Slow to Get Elsewhere)

| Data | Why Capture | Source |
|------|-------------|--------|
| Library count | Filesystem scan is slow | `scan` command |
| Class count per library | Parsing all .e files | `scan` command |
| Feature count per class | `ec.exe -short` is slow | Periodic indexing |
| Build history | Log parsing is tedious | `log compile` events |
| Test results history | Same | `log test` events |
| Git commit counts | GitHub API is slow | Git hooks |
| ECF file hashes | Detect config changes | `scan` command |

### What We DON'T Capture (Get On-Demand)

| Data | Why Not | Get Via |
|------|---------|---------|
| Full class signatures | Changes frequently, `ec.exe` is authoritative | `ec.exe -short CLASS` |
| Feature implementations | Code is in .e files | Direct file read |
| Detailed contracts | Same | `ec.exe -short` |
| Line-by-line diffs | Git is better | `git diff` |

### Metrics Tables

```sql
-- Library snapshots (updated on scan)
CREATE TABLE library_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    library TEXT,
    class_count INTEGER,
    test_count INTEGER,
    has_docs BOOLEAN,
    ecf_hash TEXT,
    scanned_at DATETIME DEFAULT CURRENT_TIMESTAMP
)

-- Daily ecosystem summary
CREATE TABLE daily_summary (
    date TEXT PRIMARY KEY,
    total_libraries INTEGER,
    total_classes INTEGER,
    total_features INTEGER,
    builds_run INTEGER,
    builds_passed INTEGER,
    tests_run INTEGER,
    tests_passed INTEGER
)
```

### Reporting Queries

```sql
-- Library growth over time
SELECT date, total_libraries FROM daily_summary ORDER BY date

-- Build success rate by library
SELECT library,
       COUNT(*) as builds,
       SUM(CASE WHEN details LIKE '%success%' THEN 1 ELSE 0 END) as passed
FROM events WHERE event_type = 'compile'
GROUP BY library

-- Most active libraries this week
SELECT library, COUNT(*) as events
FROM events
WHERE timestamp > datetime('now', '-7 days')
GROUP BY library ORDER BY events DESC
```

---

## Claude-Specific Use Cases

Things that help ME (Claude) work better across sessions:

### Session Continuity
- **Last session state**: "We were working on simple_http Phase 3"
- **Unfinished work**: "Started implementing X, didn't finish"
- **Next steps planned**: "After X, we planned to do Y"

### Error Memory
- **Fix history**: Track errors we've fixed to avoid repeating them
- **Library gotchas**: "simple_oracle had STRING_8/STRING_32 issues"
- **Common pitfalls**: Per-library warnings

### User Preferences
- **Style rules**: "Larry prefers SCOOP over threads"
- **Naming conventions**: What patterns Larry likes
- **Workflow preferences**: How Larry likes to work

### Code Generation Feedback
- **Fix tracking**: When my generated code needed corrections
- **Pattern effectiveness**: What approaches work vs get rejected
- **Learning loop**: Improve over time based on feedback

### Tool Effectiveness
- **What worked**: "For XML parsing, we used simple_xml"
- **What didn't**: "Tried X approach, had issues"
- **Time estimates**: How long similar tasks took before

### Tables for Claude Use Cases

```sql
-- Session handoffs
CREATE TABLE session_handoff (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_end DATETIME DEFAULT CURRENT_TIMESTAMP,
    current_task TEXT,
    work_in_progress TEXT,
    next_steps TEXT,
    blockers TEXT
)

-- Fix tracking (my learning loop)
CREATE TABLE fix_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    library TEXT,
    original_code TEXT,
    fix_applied TEXT,
    reason TEXT
)

-- User preferences
CREATE TABLE preferences (
    key TEXT PRIMARY KEY,
    value TEXT,
    source TEXT,  -- where we learned this
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
)
```

---

---

## Ecosystem Watchdog (Birddogging)

Monitor the simple_* ecosystem for changes without human intervention.

### What to Watch

| Event Type | Source | Capture |
|------------|--------|---------|
| New library | Filesystem scan | Library name, path, creation date |
| New ECF file | Filesystem | ECF name, library, targets |
| New class | .e file creation | Class name, file path, library |
| Feature count changes | EC.exe -short (periodic) | Delta from last scan |
| Build events | ec.exe output | Timestamp, duration, success/fail |
| Test events | Test runner output | Tests run, passed, failed |
| Git commits | Git log | Commit hash, message, files changed |

### Daemon Mode (Future)

```bash
oracle-daemon start      # Start watching filesystem
oracle-daemon stop       # Stop daemon
oracle-daemon status     # Show daemon status
```

### Watch Implementation

```eiffel
-- File watcher integration (using simple_watcher)
watch_ecosystem
    -- Watch D:\prod\simple_* for changes
    local
        watcher: SIMPLE_WATCHER
    do
        create watcher.make ("D:\prod")
        watcher.set_filter ("simple_*/**/*.e")
        watcher.on_create (agent handle_file_created)
        watcher.on_modify (agent handle_file_modified)
        watcher.on_delete (agent handle_file_deleted)
        watcher.start
    end
```

---

## Testing Strategy

### Memory-Only Mode for Test Isolation

Tests must be isolated. Use `:memory:` SQLite databases to ensure each test starts fresh.

```eiffel
-- Creation procedure for testing
make_memory_only
    -- Create oracle with in-memory database only (no persistence).
    -- Used for testing where each test needs isolation.
    do
        db_path := ":memory:"
        create memory_db.make_in_memory
        ensure_schema_in_memory
    ensure
        is_ready: is_ready
    end
```

### Test Coverage Required

- Oracle creation (both modes)
- Library registration and counting
- Event logging and retrieval
- Knowledge add/search/clear
- FTS5 MATCH queries
- Expertise injection
- Full boot sequence
- Context brief generation
- Deprecation mechanism

---

## Ideas for Future Development

1. **Natural Language Query Translation**
   - "Show failing libraries" → SQL query
   - "What did I work on yesterday?" → Filtered events
   - Use simple pattern matching, not full NLP

2. **AI Feedback Loop**
   - Track when Claude's code needed fixes
   - Learn from corrections to improve

3. **Session Summaries**
   - Auto-generate end-of-session notes
   - "Today we implemented X, fixed Y, planned Z"

4. **Confidence Scores**
   - Knowledge entries have confidence levels
   - Learnings start at high confidence, ref docs lower

5. **Source Attribution**
   - Every knowledge entry knows its source
   - "From ref_docs/patterns.md" vs "Learned 2025-01-15"

6. **Conflict Detection**
   - When new knowledge contradicts old
   - Flag for human review

7. **Export/Import**
   - Export knowledge as markdown
   - Import from other oracle instances

8. **Web Dashboard (Future)**
   - simple_web based UI for metrics
   - Visualization of ecosystem health

---

## Success Criteria

1. **Boot time < 1 second** - Expertise + context injection is fast
2. **Query response < 100ms** - Natural language queries return quickly
3. **Zero memory loss** - All context survives compression
4. **Self-documenting** - Oracle can explain itself
5. **Ecosystem awareness** - Knows all 52+ libraries and their status

### Phase 6: Proactive Guidance (Claude Attention System)
- [ ] Hook integration for context injection
- [ ] Pre-action validation (compile, git, file ops)
- [ ] Rule engine for common mistakes
- [ ] Warning injection into Claude's context
- [ ] Attention forcing mechanisms

---

## Proactive Guidance Architecture

### The Problem

Claude is stateless between tool calls. The oracle can store knowledge, but Claude only "sees" what's in the context window. There's no way to:
- Interrupt Claude mid-thought
- Push notifications to Claude
- Force Claude to pay attention

### Solution: Hook-Based Context Injection

Claude Code supports hooks that run before/after tool calls. These hooks can:
1. Validate proposed actions against oracle rules
2. Inject warnings directly into Claude's context
3. Block actions that violate rules

```
Claude proposes action → Hook fires → Oracle validates → Warning injected → Claude sees warning
```

### Implementation

**Pre-tool hooks** (`.claude/hooks/`):
```bash
# pre-bash.sh - Runs before any Bash command
if [[ "$COMMAND" == *"ec.exe"* ]]; then
    # Check: Are we in the right directory?
    # Check: Are environment variables set?
    oracle-cli validate compile "$COMMAND"
fi
```

**Oracle validation command**:
```bash
oracle-cli validate <action-type> <context>
# Returns warnings/errors that get injected into Claude's context
```

**Rule categories**:
- **Compile rules**: Right directory, env vars set, correct target
- **Code rules**: ic.item usage, SCOOP patterns, DBC requirements  
- **Git rules**: Don't commit secrets, proper message format

### Attention Forcing

Even with warnings in context, Claude might ignore them. Strategies:
- `⚠️ ORACLE CRITICAL:` prefix for high-priority warnings
- Blocking hooks that refuse to proceed without acknowledgment
- Repeated injection if mistake pattern continues

### Limitations

- Cannot guarantee Claude will follow guidance
- Hooks only fire on tool use, not on Claude's reasoning
- Requires Claude to use oracle-cli commands (not raw ec.exe)
