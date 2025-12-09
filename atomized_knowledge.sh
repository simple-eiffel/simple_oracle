#!/bin/bash
# Atomized knowledge entries from reference docs
# Run this after oracle-cli is rebuilt with the 'learn' command
# Usage: cd /d/prod/simple_oracle && ./atomized_knowledge.sh

CLI="./oracle-cli.exe"

echo "=== Ingesting Atomized Knowledge ==="

# === From eiffel_build_rules.md ===
$CLI learn rule "CD to project directory" "Always cd to the project directory before running ec.exe. The EIFGENs folder is created relative to the current working directory, not the ECF location."

$CLI learn rule "Use test target for testing" "Use the _tests target (e.g., simple_json_tests) for test compilation. Test targets include the testing library and test classes."

$CLI learn pattern "Eiffel build sequence" "Standard build: cd to project, export env vars, ec.exe -batch -config X.ecf -target X_tests -c_compile, then run ./EIFGENs/X_tests/W_code/X.exe"

# === From eric_feedback_win32_libs.md ===
$CLI learn rule "Inline C not separate files" "Use C inline external routines instead of separate .c files. Separate .c files require .obj compilation. Inline C keeps everything in one place."

$CLI learn pattern "Inline C external syntax" "Pattern: external 'C inline use header.h' alias '[C code with \$a_param for args]' end. Benefits: no .obj, simpler build, all code in one place."

$CLI learn gotcha "Win32 libs need cross-platform" "simple_console, simple_clipboard, simple_registry, simple_mmap, simple_ipc, simple_watcher, simple_system, simple_env need Linux/macOS implementations."

# === From gotchas.md - Type System ===
$CLI learn gotcha "VAPE precondition error" "Preconditions CANNOT reference private features. Create a public is_xxx status query that wraps the private check."

$CLI learn gotcha "STRING_32 vs STRING_8" "String types require explicit conversion. Use .to_string_8 for conversion. Implicit conversion causes obsolete warnings."

$CLI learn gotcha "Inline if-then-else returns ANY" "Inline conditionals return type ANY, causing VUAR(2) errors. Use explicit local variable with regular if-then-else instead."

$CLI learn gotcha "EIFGENs read-only" "NEVER modify files in EIFGENs - this is EiffelStudio workspace. Segfaults often indicate corruption. Fix with -clean flag."

$CLI learn rule "rescue/retry external only" "ONLY use rescue/retry for external systems (COM, C libs, network). Never use to mask precondition failures in internal code."

$CLI learn gotcha "Percent escape in strings" "In Eiffel manifest strings, use %% for literal percent sign. Single % is escape character."

$CLI learn gotcha "ECF UUID must be unique" "EiffelStudio uses UUIDs to identify libraries. Duplicate/fake UUIDs cause wrong classes to load. Generate real UUIDs with PowerShell: [guid]::NewGuid()"

$CLI learn rule "Use TEST_SET_BASE not EQA" "Use TEST_SET_BASE from simple_testing, not EQA_TEST_SET directly. Provides consistent assertions and helpers."

$CLI learn gotcha "ARRAYED_LIST has uses reference" "ARRAYED_LIST.has uses = (reference equality). For value equality use: across list as ic some ic ~ value end"

$CLI learn gotcha "Inline agents cant access locals" "Inline agents cannot capture or modify local variables. Use class attribute and named agent instead."

$CLI learn gotcha "VDUS cannot undefine deferred" "Cannot undefine already-deferred features. Undefine converts effective to deferred, not reverse. Just inherit both - feature joining handles it."

$CLI learn gotcha "HASH_TABLE across loop" "In across table as ic, ic gives VALUE directly. For KEY use @ic.key. Do not use internal cursor methods like key_for_iteration."

$CLI learn gotcha "Gobo DS_LIST iteration" "Gobo DS_LIST doesnt support across. Use cursor-based from/until/loop with new_cursor.start/after/forth pattern."

# === From patterns.md - Key Patterns ===
$CLI learn pattern "Public status query" "Create public is_ready: BOOLEAN queries that wrap private state checks. Use these in preconditions to avoid VAPE errors."

$CLI learn pattern "Postcondition with old" "Use old expression in postconditions: count_increased: items.count = old items.count + 1. Always specify what changed AND what didnt change."

$CLI learn pattern "Value equality in collections" "For value comparison in lists use: across list as ic some ic ~ target end. The ~ operator is value equality."

$CLI learn pattern "MI mixin for handlers" "Extract feature groups into deferred mixin classes inheriting shared state base. All handlers share Current at runtime. Replaces pub-sub/DI/mediator patterns."

$CLI learn pattern "Once function singleton" "Use once functions for shared state between instances: router: ROUTER once create Result end. WSF creates new execution per request."

$CLI learn pattern "Agent-based routes" "Register routes with agents: server.on_get (/api/users, agent handle_users). Enables clean separation of route config from handlers."

$CLI learn pattern "Middleware pipeline" "Chain middleware using recursive agents. Each middleware receives a_next procedure to call for continuation."

# === From RESUME_POINT.md - Ecosystem ===
$CLI learn insight "Inline C blocks independent" "Each inline C block compiles independently. Preprocessor guards dont persist, static vars not shared, struct defs not visible across functions."

$CLI learn insight "51 simple libraries" "Ecosystem has 51 simple_* libraries: 43 with code, 8 placeholders. All have README.md, CHANGELOG.md, docs/index.html, API docs."

$CLI learn pattern "Seven-step research" "Before implementing library: research existing solutions, analyze competition, design API, then implement. Reports in reference_docs/research/."

echo ""
echo "=== Ingestion Complete ==="
$CLI status
