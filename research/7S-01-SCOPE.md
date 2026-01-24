# 7S-01: SCOPE - simple_oracle


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Problem Statement

Claude's context window is limited, and context compression loses important development state. Working on the Simple Eiffel ecosystem requires persistent memory of:
- What was worked on
- What's failing
- What patterns to follow
- What mistakes to avoid

## Library Purpose

simple_oracle provides Claude's external memory and development intelligence:

1. **MEMORY** - Persistent storage that survives context compression
2. **MONITORING** - Real-time tracking of compiles, tests, git, file changes
3. **KNOWLEDGE** - Indexed reference docs, APIs, patterns (FTS5 searchable)
4. **CONTEXT** - Instant briefing on current state for fresh sessions
5. **HANDOFF** - Session continuity across context boundaries

## Target Users

- Claude (primary user) as development partner
- Larry (human) for ecosystem metrics
- Automated tools for ecosystem health checks

## Scope Boundaries

### In Scope
- SQLite database (memory + disk)
- FTS5 full-text search for knowledge
- Event logging (compile, test, git, errors)
- Session handoff for context continuity
- Expertise injection (boot sequence)
- Natural language queries
- Ecosystem statistics and metrics
- Compiled stats from EIFGENs metadata
- Proactive guidance (check command)

### Out of Scope
- File watching (separate daemon)
- Git hook integration
- IDE integration
- Web dashboard

## Success Metrics

- Boot sequence under 1 second
- Query response under 100ms
- Knowledge retrieval relevance > 90%
- Zero data loss on context compression
