<p align="center">
  <img src="https://raw.githubusercontent.com/simple-eiffel/claude_eiffel_op_docs/main/artwork/LOGO.png" alt="simple_ library logo" width="400">
</p>

# SIMPLE_ORACLE
### Claude's External Memory and Development Intelligence Platform

[![Language](https://img.shields.io/badge/language-Eiffel-blue.svg)](https://www.eiffel.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()
[![Documentation](https://img.shields.io/badge/docs-HTML-purple.svg)](docs/index.html)
[![SCOOP](https://img.shields.io/badge/SCOOP-compatible-brightgreen.svg)]()

---

## Overview

**SIMPLE_ORACLE** is a persistent memory and development intelligence platform for AI-assisted software development. It solves the fundamental problem of AI context limits by providing Claude (or any AI assistant) with a durable external memory that survives across sessions.

The system tracks:
- **53+ Eiffel libraries** in the simple_* ecosystem
- **Compilation and test history** with success/failure patterns
- **Git commits** across all libraries
- **Knowledge base** with searchable patterns, rules, and gotchas
- **Session handoffs** for seamless context continuity

**Core insight:** When Claude's context window compresses, the oracle remembers everything. Run `oracle-cli boot` at session start and you're back to full context instantly.

**Developed using AI-assisted methodology:** Built interactively with Claude following rigorous Design by Contract principles.

---

## Documentation

Full HTML documentation is available at **[docs/index.html](docs/index.html)**.

The documentation includes:
- Quick start guide
- Complete commands reference
- Feature overview with examples
- API documentation
- Claude Code integration guide

---

## Quick Start

### Boot Sequence (Every Session)

```bash
oracle-cli boot
```

This single command:
1. Injects Eiffel expertise (SCOOP, DBC, void safety, patterns)
2. Shows last session's handoff (what you were working on)
3. Provides current ecosystem context (libraries, recent activity)
4. Reports any problems (failing tests, build issues)

### Common Commands

```bash
# Query the knowledge base
oracle-cli query "what libraries use inline C?"
oracle-cli query "show failing tests"
oracle-cli query "how do I use SCOOP?"

# Compile and test
oracle-cli compile simple_json              # Compiles and logs result
oracle-cli test simple_json                 # Runs tests and logs result
oracle-cli compiles                         # Show compile history
oracle-cli tests                            # Show test history

# Track git activity
oracle-cli git simple_json 10               # Log last 10 commits
oracle-cli commits                          # Show recent commits

# End of session
oracle-cli handoff "Implementing feature X" "Core done, tests pending" "Add edge cases" "None"
```

---

## Installation

### Prerequisites

- EiffelStudio 25.02+
- SQLite (via simple_sql)
- simple_* ecosystem libraries

### Build

```bash
cd /d/prod/simple_oracle

# Set environment variables
export SIMPLE_ORACLE=/d/prod/simple_oracle
export SIMPLE_SQL=/d/prod/simple_sql
export SIMPLE_JSON=/d/prod/simple_json
export SIMPLE_FILE=/d/prod/simple_file
export SIMPLE_PROCESS=/d/prod/simple_process
export SIMPLE_DATETIME=/d/prod/simple_datetime
export SIMPLE_LOGGER=/d/prod/simple_logger
export SIMPLE_WATCHER=/d/prod/simple_watcher

# Compile CLI
ec -batch -config simple_oracle.ecf -target simple_oracle_cli -c_compile

# The executable will be at:
# ./EIFGENs/simple_oracle_cli/W_code/simple_oracle.exe
```

### ECF Integration

```xml
<library name="simple_oracle" location="$SIMPLE_ORACLE/simple_oracle.ecf"/>
```

---

## Architecture

```
SIMPLE_ORACLE (Core)
    |-- Knowledge Base (FTS5 full-text search)
    |   |-- Patterns, rules, gotchas, decisions
    |   |-- Ingested from reference_docs/
    |   +-- Natural language queries
    |
    |-- Event Log
    |   |-- Compiles (success/failure, duration)
    |   |-- Tests (passed/failed counts)
    |   |-- Git commits (hash, message, stats)
    |   +-- Custom events
    |
    |-- Ecosystem Scanner
    |   |-- Library discovery (D:\prod\simple_*)
    |   |-- Class extraction from .e files
    |   |-- Feature parsing with contracts
    |   +-- Dependency analysis
    |
    +-- Session Management
        |-- Handoff recording
        |-- Context injection (boot)
        +-- Expertise packets

ORACLE_CLI (Command Line Interface)
    +-- All commands exposed via oracle-cli executable
```

---

## Commands Reference

### Session Management

| Command | Description | Example |
|---------|-------------|---------|
| `boot` | Full boot sequence - expertise + context | `oracle-cli boot` |
| `handoff` | Record/view session handoff | `oracle-cli handoff "task" "wip" "next" "blockers"` |
| `check` | Show guidance (when told "see oracle") | `oracle-cli check` |

### Knowledge Base

| Command | Description | Example |
|---------|-------------|---------|
| `query` | Natural language search | `oracle-cli query "inline C patterns"` |
| `learn` | Add knowledge entry | `oracle-cli learn rule "Always use SCOOP" "..."` |
| `ingest` | Ingest docs from directory | `oracle-cli ingest D:\prod\reference_docs` |

### Development Tracking

| Command | Description | Example |
|---------|-------------|---------|
| `compile` | Run ec.exe and log result | `oracle-cli compile simple_json` |
| `compiles` | Show compile history | `oracle-cli compiles` |
| `test` | Run tests and log result | `oracle-cli test simple_json` |
| `tests` | Show test history | `oracle-cli tests` |

### Git Integration

| Command | Description | Example |
|---------|-------------|---------|
| `git` | Scan and log commits | `oracle-cli git simple_json 10` |
| `commits` | Show recent commits | `oracle-cli commits` |

### Ecosystem

| Command | Description | Example |
|---------|-------------|---------|
| `status` | Ecosystem health check | `oracle-cli status` |
| `stats` | Metrics for period | `oracle-cli stats month` |
| `scan` | Rescan filesystem | `oracle-cli scan` |

---

## The Boot Sequence

When you run `oracle-cli boot`, the oracle outputs a structured context packet:

```
=== EIFFEL EXPERTISE INJECTION ===
YOU ARE: Larry's Eiffel development partner. Expert in DBC, void safety, SCOOP.

EIFFEL CORE:
- DBC: require(pre) ensure(post) invariant(class) - ALWAYS use contracts
- Void safe: detachable(maybe null) attached(never null)
- SCOOP: separate x | across sep as cursor loop ... end
...

=== LAST SESSION HANDOFF ===
Recorded: 2025-12-09 19:00:32
Current Task: Implementing LSP for VSCode
Work In Progress: Parser complete, symbol indexer 60%
Next Steps: JSON-RPC server, VSCode extension
Blockers: None

=== ORACLE CONTEXT BRIEF ===
Libraries: 53
Recent Activity (4h):
  [compile] simple_json: SUCCESS (5s)
  [test] simple_oracle: 45/45 passed
  [git] simple_web: commit abc123: Add SCOOP capability
...
```

This is injected into Claude's context at session start, providing full awareness of:
- Eiffel language patterns and rules
- What was being worked on
- Current ecosystem state
- Any problems requiring attention

---

## Knowledge Base

The oracle maintains a searchable knowledge base using SQLite FTS5 (full-text search).

### Knowledge Categories

- **pattern** - Reusable code patterns
- **rule** - Critical rules that must be followed
- **gotcha** - Common mistakes and their solutions
- **decision** - Design decisions and rationale
- **insight** - Observations and learnings

### Adding Knowledge

```bash
# Learn a rule
oracle-cli learn rule "Use simple_process" "Always use simple_process, never ISE process library"

# Learn a pattern
oracle-cli learn pattern "Inline C" "external \"C inline use %%\"header.h%%\"\" alias \"...\""

# Learn a gotcha
oracle-cli learn gotcha "ARRAYED_LIST iteration" "Use ic not ic.item - ic is already the element"
```

### Querying

```bash
oracle-cli query "how do I use inline C?"
oracle-cli query "what are the SCOOP rules?"
oracle-cli query "show me gotchas"
```

---

## Integration with Claude Code

### Claude Code Hook (Auto-boot)

Add to `.claude/hooks/session-start.ps1`:

```powershell
$ORACLE_CLI = "D:\prod\simple_oracle\oracle-cli.exe"
if (Test-Path $ORACLE_CLI) {
    $BOOT_OUTPUT = & $ORACLE_CLI boot 2>&1
    Write-Output "=== ORACLE AUTO-BOOT ==="
    Write-Output $BOOT_OUTPUT
    Write-Output "=== END ORACLE BOOT ==="
}
exit 0
```

### CLAUDE.md Integration

Add to your project's `CLAUDE.md`:

```markdown
## ORACLE BOOT SEQUENCE

**On every new session, run:**

oracle-cli boot


**When Larry says "consult oracle" or "see oracle", run:**

oracle-cli check

```

---

## Database Schema

The oracle uses SQLite with the following tables:

```sql
-- Libraries discovered via scan
libraries (id, name, path, last_scanned)

-- Knowledge base with FTS5
knowledge (id, category, title, content, source_file, created_at)
knowledge_fts (FTS5 virtual table for full-text search)

-- Event log
events (id, event_type, library, details, timestamp)

-- Compile history
compiles (id, library, target, success, duration, timestamp)

-- Test history
test_runs (id, library, target, total, passed, failed, duration, output, timestamp)

-- Git commits
commits (id, library, hash, author, message, files, insertions, deletions, timestamp)

-- Session handoffs
handoffs (id, current_task, work_in_progress, next_steps, blockers, timestamp)

-- Ecosystem scanner results
classes (id, library_id, name, file_path, has_contracts)
features (id, class_id, name, signature, has_precondition, has_postcondition)
```

---

## Design Principles

### Design by Contract

Every feature includes contracts:

```eiffel
query (a_question: STRING_32): STRING_32
    require
        question_not_empty: not a_question.is_empty
        is_ready: is_ready
    do
        -- FTS5 search implementation
    ensure
        result_attached: Result /= Void
    end
```

### SCOOP Compatible

The library is designed for concurrent access:

```xml
<capability>
    <concurrency support="scoop"/>
    <void_safety support="all"/>
</capability>
```

### Void Safety

All types properly declared:

```eiffel
last_error: detachable STRING_32
    -- Error message if has_error, Void otherwise

oracle: SIMPLE_ORACLE
    -- Always attached after initialization
```

---

## Dependencies

| Library | Purpose |
|---------|---------|
| simple_sql | SQLite database access |
| simple_json | JSON parsing for structured data |
| simple_file | File system operations |
| simple_process | External command execution |
| simple_datetime | Timestamp handling |
| simple_logger | Logging (optional) |
| simple_watcher | File watching (optional) |

---

## API Overview

### SIMPLE_ORACLE (Core)

```eiffel
class SIMPLE_ORACLE

feature -- Initialization
    make
        -- Initialize oracle with default database

feature -- Status
    is_ready: BOOLEAN
    has_error: BOOLEAN
    last_error: detachable STRING_32
    library_count: INTEGER
    knowledge_count: INTEGER

feature -- Boot
    full_boot: STRING_32
        -- Complete boot sequence with expertise + context
    inject_expertise: STRING_32
        -- Eiffel expertise packet
    context_brief: STRING_32
        -- Current ecosystem summary

feature -- Knowledge
    query (a_question: STRING_32): STRING_32
    add_knowledge (a_category, a_title, a_content: STRING_32)
    ingest_directory (a_path: STRING_32)
    clear_knowledge

feature -- Events
    log_event (a_type, a_library, a_details: STRING_32)
    log_compile (a_library, a_target: STRING_32; a_success: BOOLEAN; a_duration: REAL_64)
    log_test_run (a_library, a_target: STRING_32; a_total, a_passed, a_failed: INTEGER; ...)
    log_git_commit (a_library, a_hash, a_author, a_message: STRING_32; ...)
    recent_events (a_hours: INTEGER): LIST [ORACLE_EVENT]
    recent_compiles (a_count: INTEGER): LIST [COMPILE_RECORD]
    recent_test_runs (a_count: INTEGER): LIST [TEST_RUN_RECORD]
    recent_commits (a_count: INTEGER): LIST [COMMIT_RECORD]

feature -- Session
    record_handoff (a_task, a_wip, a_next, a_blockers: detachable STRING_32)
    handoff_brief: STRING_32
    check_guidance: STRING_32

feature -- Stats
    ecosystem_stats (a_period: STRING_32): STRING_32
    failing_libraries: LIST [FAILING_LIBRARY]
    git_stats: TUPLE [total_commits, libraries_with_commits, total_insertions, total_deletions: INTEGER]

feature -- Cleanup
    close
        -- Close database connections
end
```

---

## Project Structure

```
simple_oracle/
|-- src/
|   |-- simple_oracle.e           -- Core oracle class
|   |-- oracle_cli.e              -- Command-line interface
|   |-- oracle_ecosystem_scanner.e -- Library/class discovery
|   |-- oracle_knowledge_base.e   -- FTS5 knowledge management
|   +-- support/
|       |-- oracle_event.e        -- Event record
|       |-- compile_record.e      -- Compile history record
|       |-- test_run_record.e     -- Test history record
|       +-- commit_record.e       -- Git commit record
|-- testing/
|   +-- test_simple_oracle.e      -- Test suite
|-- docs/
|   |-- index.html                -- Documentation home
|   +-- css/style.css             -- Stylesheet
|-- simple_oracle.ecf             -- ECF configuration
|-- README.md                     -- This file
|-- CHANGELOG.md                  -- Version history
+-- LICENSE                       -- MIT License
```

---

## Why SIMPLE_ORACLE?

### The Problem

AI assistants have limited context windows. After extended sessions, context compresses and loses important state:
- What was being worked on?
- Which tests are failing?
- What patterns should be followed?
- What mistakes were made before?

### The Solution

SIMPLE_ORACLE provides:
1. **Persistent Memory** - SQLite database survives sessions
2. **Instant Context** - `boot` command restores full awareness
3. **Searchable Knowledge** - FTS5 for natural language queries
4. **Activity Tracking** - Compiles, tests, git history logged
5. **Session Handoffs** - Explicit continuity mechanism

### The Result

Start a new Claude session, run `oracle-cli boot`, and immediately have:
- Full Eiffel expertise
- Knowledge of what you were working on
- Current ecosystem status
- Any problems requiring attention

No lost context. No re-explaining. Just continuity.

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Resources

- [simple_* Ecosystem](https://github.com/simple-eiffel)
- [Eiffel Software](https://www.eiffel.org/)
- [SQLite FTS5](https://www.sqlite.org/fts5.html)

---

## Contact

- **Author:** Larry Rix
- **Repository:** https://github.com/simple-eiffel/simple_oracle
- **Issues:** https://github.com/simple-eiffel/simple_oracle/issues

---

**Built with Eiffel's Design by Contract principles for maximum reliability.**

**Designed to give AI assistants the persistent memory they need for effective collaboration.**
