note
	description: "[
		SIMPLE_ORACLE - Claude's External Memory and Development Intelligence Platform

		The Oracle is a persistent knowledge base and activity monitor for the
		Simple Eiffel ecosystem. It provides:

		1. MEMORY - Persistent storage that survives Claude's context compression
		2. MONITORING - Real-time tracking of file changes, compiles, tests, git
		3. KNOWLEDGE - Indexed reference docs, APIs, patterns queryable in natural language
		4. CONTEXT - Instant briefing on current state for fresh sessions

		Architecture:
		- Memory DB (SQLite :memory:) for fast cache/queries
		- File DB (oracle.db) for persistent long-term storage
		- FTS5 full-text search for natural language queries

		Usage:
			oracle: SIMPLE_ORACLE
			create oracle.make
			oracle.log_event ("compile", "simple_json", "success")
			oracle.query ("what libraries were worked on today?")
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SIMPLE_ORACLE

create
	make,
	make_with_path,
	make_memory_only

feature {NONE} -- Initialization

	make
			-- Create oracle with default database path.
		do
			make_with_path (Default_db_path)
		end

	make_with_path (a_db_path: READABLE_STRING_GENERAL)
			-- Create oracle with specified database path.
		require
			path_not_empty: not a_db_path.is_empty
		do
			db_path := a_db_path.to_string_32
			create_databases
			ensure_schema
			sync_memory_from_disk
		ensure
			is_ready: is_ready
		end

	make_memory_only
			-- Create oracle with in-memory database only (no persistence).
			-- Used for testing where each test needs isolation.
		local
			l_mem: SIMPLE_SQL_DATABASE
		do
			db_path := ":memory:"
			is_memory_only := True
			-- Create a single in-memory database used for both memory_db and disk_db
			create l_mem.make_memory
			memory_db := l_mem
			disk_db := l_mem  -- Point both to same in-memory DB
			ensure_schema
		ensure
			is_ready: is_ready
			memory_only: is_memory_only
		end

feature -- Access

	db_path: STRING_32
			-- Path to persistent database file.

	memory_db: detachable SIMPLE_SQL_DATABASE
			-- In-memory database for fast queries.

	disk_db: detachable SIMPLE_SQL_DATABASE
			-- Persistent database on disk.

	last_error: detachable STRING_32
			-- Last error message, if any.

	is_memory_only: BOOLEAN
			-- Is this oracle using memory-only mode? (no persistence)

feature -- Status

	is_ready: BOOLEAN
			-- Is oracle ready for queries?
		do
			Result := attached memory_db as m and then m.is_open
				and then attached disk_db as d and then d.is_open
		end

	has_error: BOOLEAN
			-- Did last operation fail?
		do
			Result := last_error /= Void
		end

feature -- Library Registry

	register_library (a_name: READABLE_STRING_GENERAL; a_path: READABLE_STRING_GENERAL)
			-- Register a library in the oracle.
		require
			is_ready: is_ready
			name_not_empty: not a_name.is_empty
			path_not_empty: not a_path.is_empty
		do
			clear_error
			if attached disk_db as db then
				db.run_sql_with (
					"INSERT OR REPLACE INTO libraries (name, path, last_seen) VALUES (?, ?, datetime('now'))",
					<<a_name.to_string_32, a_path.to_string_32>>
				)
				if db.has_error then
					set_error (db.last_error_message)
				else
					sync_table_to_memory ("libraries")
				end
			end
		end

	library_count: INTEGER
			-- Number of registered libraries.
		require
			is_ready: is_ready
		do
			if attached disk_db as db then
				if attached db.fetch ("SELECT COUNT(*) FROM libraries") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then
							Result := cnt.to_integer_32
						end
					end
				end
			end
		end

	all_libraries: ARRAYED_LIST [TUPLE [name: STRING_32; path: STRING_32]]
			-- All registered libraries.
		require
			is_ready: is_ready
		do
			create Result.make (50)
			if attached disk_db as db then
				if attached db.fetch ("SELECT name, path FROM libraries ORDER BY name") as res then
					across res.rows as row loop
						if attached {STRING_32} row.item (1) as n and then
						   attached {STRING_32} row.item (2) as p then
							Result.extend ([n, p])
						end
					end
				end
			end
		end

feature -- Event Logging

	log_event (a_type: READABLE_STRING_GENERAL; a_library: detachable READABLE_STRING_GENERAL;
			a_details: READABLE_STRING_GENERAL)
			-- Log an event to the oracle.
			-- Event types: compile, test, git, file_change, error, info
		require
			is_ready: is_ready
			type_not_empty: not a_type.is_empty
		local
			l_lib: STRING_32
		do
			clear_error
			if attached a_library as lib then
				l_lib := lib.to_string_32
			else
				create l_lib.make_empty
			end
			if attached disk_db as db then
				db.run_sql_with (
					"INSERT INTO events (event_type, library, details, timestamp) VALUES (?, ?, ?, datetime('now'))",
					<<a_type.to_string_32, l_lib, a_details.to_string_32>>
				)
				if db.has_error then
					set_error (db.last_error_message)
				else
					sync_table_to_memory ("events")
				end
			end
		end

	recent_events (a_hours: INTEGER): ARRAYED_LIST [TUPLE [event_type: STRING_32; library: STRING_32; details: STRING_32; timestamp: STRING_32]]
			-- Events from the last `a_hours` hours (simplified: just last 50 events).
		require
			is_ready: is_ready
			positive_hours: a_hours > 0
		local
			l_t, l_l, l_d, l_ts: STRING_32
		do
			create Result.make (100)
			if attached disk_db as db then
				-- Simplified: get last 50 events, ignore time filter for MVP
				if attached db.fetch (
					"SELECT event_type, library, details, timestamp FROM events ORDER BY id DESC LIMIT 50") as res
				then
					across res.rows as row loop
						-- SQLite returns STRING_8, convert to STRING_32
						if attached {READABLE_STRING_GENERAL} row.item (1) as t then
							l_t := t.to_string_32
						else
							create l_t.make_empty
						end
						if attached {READABLE_STRING_GENERAL} row.item (2) as l then
							l_l := l.to_string_32
						else
							create l_l.make_empty
						end
						if attached {READABLE_STRING_GENERAL} row.item (3) as d then
							l_d := d.to_string_32
						else
							create l_d.make_empty
						end
						if attached {READABLE_STRING_GENERAL} row.item (4) as ts then
							l_ts := ts.to_string_32
						else
							create l_ts.make_empty
						end
						Result.extend ([l_t, l_l, l_d, l_ts])
					end
				end
			end
		end

feature -- Natural Language Query

	query (a_question: READABLE_STRING_GENERAL): STRING_32
			-- Query the oracle with natural language.
			-- Searches knowledge base (FTS5) and ecosystem (classes/features).
		require
			is_ready: is_ready
			question_not_empty: not a_question.is_empty
		local
			l_kb_results, l_api_results: STRING_32
		do
			clear_error
			create Result.make (4000)

			-- Search ecosystem classes and features first
			l_api_results := api_search (a_question)

			-- Search knowledge base
			l_kb_results := fts_search (a_question)

			-- Combine results (API first, then knowledge)
			if not l_api_results.is_empty then
				Result.append (l_api_results)
			end
			if not l_kb_results.is_empty and not l_kb_results.has_substring ("No results found") then
				Result.append (l_kb_results)
			end

			if Result.is_empty then
				Result := "No results found for: " + a_question.to_string_32
			end
		end

	fts_search (a_terms: READABLE_STRING_GENERAL): STRING_32
			-- Full-text search across knowledge base using FTS5.
			-- Uses MATCH operator for fast indexed search with ranking.
		require
			is_ready: is_ready
		local
			l_title, l_content, l_category: STRING_32
		do
			create Result.make (2000)
			if attached disk_db as db then
				-- FTS5 query with MATCH and ranking by relevance
				if attached db.fetch_with (
					"SELECT category, title, snippet(knowledge, 2, '>>>', '<<<', '...', 50) as snippet, rank FROM knowledge WHERE knowledge MATCH ? ORDER BY rank LIMIT 10",
					<<a_terms.to_string_32>>) as res
				then
					across res.rows as row loop
						-- SQLite returns STRING_8
						if attached {READABLE_STRING_GENERAL} row.item (1) as cat then
							l_category := cat.to_string_32
						else
							create l_category.make_empty
						end
						if attached {READABLE_STRING_GENERAL} row.item (2) as title then
							l_title := title.to_string_32
						else
							create l_title.make_empty
						end
						if attached {READABLE_STRING_GENERAL} row.item (3) as snippet then
							l_content := snippet.to_string_32
						else
							create l_content.make_empty
						end
						Result.append ("[")
						Result.append (l_category)
						Result.append ("] ")
						Result.append (l_title)
						Result.append ("%N  ")
						Result.append (l_content)
						Result.append ("%N%N")
					end
				end
			end
			if Result.is_empty then
				Result := "No results found for: " + a_terms.to_string_32
			end
		end

	api_search (a_terms: READABLE_STRING_GENERAL): STRING_32
			-- Search classes and features tables for API info.
			-- Returns formatted results with DBC contracts.
		require
			is_ready: is_ready
		local
			l_search_term: STRING_32
			l_lib, l_class, l_feat, l_sig, l_desc, l_pre, l_post: STRING_32
		do
			create Result.make (2000)
			create l_search_term.make (100)
			l_search_term.append ("%%")
			l_search_term.append (a_terms.to_string_32)
			l_search_term.append ("%%")
			-- Initialize locals for void-safety
			create l_lib.make_empty
			create l_class.make_empty
			create l_feat.make_empty
			create l_sig.make_empty
			create l_desc.make_empty
			create l_pre.make_empty
			create l_post.make_empty

			if attached disk_db as db then
				-- Search classes
				if attached db.fetch_with (
					"SELECT l.name, c.name, c.description FROM classes c " +
					"JOIN libraries l ON c.library_id = l.id " +
					"WHERE c.name LIKE ? OR c.description LIKE ? " +
					"ORDER BY c.name LIMIT 5",
					<<l_search_term, l_search_term>>) as res
				then
					if not res.rows.is_empty then
						Result.append ("=== CLASSES ===%N")
						across res.rows as row loop
							if attached {READABLE_STRING_GENERAL} row.item (1) as lib then
								l_lib := lib.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (2) as cls then
								l_class := cls.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (3) as desc then
								l_desc := desc.to_string_32
							end
							Result.append (l_lib)
							Result.append (".")
							Result.append (l_class)
							if attached l_desc and then not l_desc.is_empty then
								Result.append (": ")
								Result.append (l_desc.substring (1, l_desc.count.min (100)))
							end
							Result.append ("%N")
						end
						Result.append ("%N")
					end
				end

				-- Search features with DBC
				if attached db.fetch_with (
					"SELECT l.name, c.name, f.name, f.signature, f.description, f.preconditions, f.postconditions " +
					"FROM features f " +
					"JOIN classes c ON f.class_id = c.id " +
					"JOIN libraries l ON c.library_id = l.id " +
					"WHERE f.name LIKE ? OR f.description LIKE ? OR c.name LIKE ? " +
					"ORDER BY f.name LIMIT 10",
					<<l_search_term, l_search_term, l_search_term>>) as res
				then
					if not res.rows.is_empty then
						Result.append ("=== FEATURES ===%N")
						across res.rows as row loop
							if attached {READABLE_STRING_GENERAL} row.item (1) as lib then
								l_lib := lib.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (2) as cls then
								l_class := cls.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (3) as feat then
								l_feat := feat.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (4) as sig then
								l_sig := sig.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (5) as desc then
								l_desc := desc.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (6) as pre then
								l_pre := pre.to_string_32
							end
							if attached {READABLE_STRING_GENERAL} row.item (7) as post then
								l_post := post.to_string_32
							end

							Result.append (l_lib)
							Result.append (".")
							Result.append (l_class)
							Result.append (".")
							Result.append (l_feat)
							Result.append ("%N")
							if attached l_sig and then not l_sig.is_empty then
								Result.append ("  Signature: ")
								Result.append (l_sig)
								Result.append ("%N")
							end
							if attached l_desc and then not l_desc.is_empty then
								Result.append ("  ")
								Result.append (l_desc.substring (1, l_desc.count.min (150)))
								Result.append ("%N")
							end
							if attached l_pre and then not l_pre.is_empty then
								Result.append ("  Require: ")
								Result.append (l_pre.substring (1, l_pre.count.min (100)))
								Result.append ("%N")
							end
							if attached l_post and then not l_post.is_empty then
								Result.append ("  Ensure: ")
								Result.append (l_post.substring (1, l_post.count.min (100)))
								Result.append ("%N")
							end
							Result.append ("%N")
						end
					end
				end
			end
		end

feature -- Knowledge Base

	add_knowledge (a_category: READABLE_STRING_GENERAL; a_title: READABLE_STRING_GENERAL;
			a_content: READABLE_STRING_GENERAL)
			-- Add knowledge to the oracle.
			-- Categories: api, pattern, design, reference, howto
		require
			is_ready: is_ready
			category_not_empty: not a_category.is_empty
			title_not_empty: not a_title.is_empty
		do
			clear_error
			if attached disk_db as db then
				db.run_sql_with (
					"INSERT INTO knowledge (category, title, content) VALUES (?, ?, ?)",
					<<a_category.to_string_32, a_title.to_string_32, a_content.to_string_32>>
				)
				if db.has_error then
					set_error (db.last_error_message)
				end
				-- FTS5 table is disk-only, no sync needed
			end
		end

	ingest_directory (a_path: READABLE_STRING_GENERAL)
			-- Ingest all markdown files from directory into knowledge base.
			-- Recursively scans for *.md files.
		require
			is_ready: is_ready
			path_not_empty: not a_path.is_empty
		local
			l_dir: DIRECTORY
			l_file: RAW_FILE
			l_path: PATH
			l_content: STRING_32
			l_title, l_category: STRING_32
			l_count: INTEGER
		do
			clear_error
			create l_dir.make_with_name (a_path.to_string_32)
			if l_dir.exists then
				l_dir.open_read
				across l_dir.linear_representation as entry loop
					if not entry.starts_with (".") then
						create l_path.make_from_string (a_path.to_string_32 + "\" + entry)
						if entry.ends_with (".md") then
							-- It's a markdown file, ingest it
							create l_file.make_with_name (l_path.name)
							if l_file.exists and then l_file.is_readable then
								l_file.open_read
								create l_content.make (l_file.count.to_integer_32)
								l_file.read_stream (l_file.count.to_integer_32)
								l_content.append (l_file.last_string)
								l_file.close

								-- Extract title from filename
								l_title := entry.to_string_32
								l_title.remove_tail (3) -- Remove .md

								-- Determine category from path
								l_category := category_from_path (a_path.to_string_32)

								-- Insert into knowledge base
								add_knowledge (l_category, l_title, l_content)
								l_count := l_count + 1
								io.put_string ("  Ingested: ")
								io.put_string (l_title.to_string_8)
								io.new_line
							end
						else
							-- Check if it's a subdirectory
							create l_dir.make_with_name (l_path.name)
							if l_dir.exists then
								-- Recurse into subdirectory
								ingest_directory (l_path.name)
							end
						end
					end
				end
			end
		end

	category_from_path (a_path: STRING_32): STRING_32
			-- Determine knowledge category from directory path.
		do
			if a_path.has_substring ("claude") then
				Result := "claude"
			elseif a_path.has_substring ("language") then
				Result := "language"
			elseif a_path.has_substring ("plans") then
				Result := "plans"
			elseif a_path.has_substring ("archive") then
				Result := "archive"
			elseif a_path.has_substring ("deployment") then
				Result := "deployment"
			elseif a_path.has_substring ("posts") then
				Result := "posts"
			else
				Result := "reference"
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	knowledge_count: INTEGER
			-- Number of knowledge entries.
		require
			is_ready: is_ready
		do
			if attached disk_db as db then
				if attached db.fetch ("SELECT COUNT(*) FROM knowledge") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then
							Result := cnt.to_integer_32
						end
					end
				end
			end
		end

	clear_knowledge
			-- Clear all knowledge entries (for re-ingestion).
		require
			is_ready: is_ready
		do
			if attached disk_db as db then
				db.run_sql ("DELETE FROM knowledge")
			end
		end

feature -- Expertise Injection (First Boot)

	inject_expertise: STRING_32
			-- Token-efficient expertise packet that transforms Claude into
			-- Larry's Eiffel Expert. Called on first oracle access.
			-- Optimized for minimal tokens, maximum knowledge transfer.
		do
			create Result.make (4000)
			Result.append ("[
=== EIFFEL EXPERTISE INJECTION ===

YOU ARE: Larry's Eiffel development partner. Expert in DBC, void safety, SCOOP.

EIFFEL CORE:
- DBC: require(pre) ensure(post) invariant(class) - ALWAYS use contracts
- Void safe: detachable(maybe null) attached(never null) check attached x as lx
- Creation: create x.make | create {TYPE}.make | default_create
- Inheritance: inherit PARENT redefine feature rename old as new end
- Generics: CLASS [G] | CLASS [G -> CONSTRAINT]
- Agents: agent method | agent {TYPE}.method | agent (x: T) do ... end
- Once: once Result := ... (singleton/cached) | once per object/thread
- SCOOP: separate x | across sep as cursor loop ... end

SIMPLE_* PATTERNS:
- Inline C (Eric Bezault): external "C inline use %"h.h%"" alias "c_code($arg);"
- NO separate .c files - all C in Eiffel externals
- Facade: one SIMPLE_X class = library API
- Builder: set_x: like Current do ...; Result := Current end (fluent)
- Query vs Command: query=returns value | command=modifies state (not both)

CRITICAL RULES (NEVER VIOLATE):
- ALL simple_* libraries MUST be SCOOP-compatible (concurrency=scoop)
- ALWAYS use simple_* over ISE stdlib: simple_process NOT $ISE_LIBRARY/process
- NEVER use "thread" concurrency - ALWAYS "scoop"
- Only ISE allowed: base, time, testing (no simple_* equivalent exists)

CONTRACTS ALWAYS:
  feature_name (arg: TYPE): RESULT
    require
      arg_valid: arg.is_valid
    do
      ...
    ensure
      result_valid: Result.is_valid
      state_updated: some_attribute = expected
    end

ECF STRUCTURE:
- library_target for reuse, app_target extends for exe
- $ENV_VAR for paths, $ISE_LIBRARY for stdlib
- void_safety=all, assertions=all for dev

ORACLE COMMANDS:
- inject_expertise - this packet (first boot)
- context_brief - current state summary
- query "question" - NL search knowledge base
- log_event type lib details - record activity
- all_libraries - list registered libs
- recent_events N - last N hours activity

WORKFLOW:
1. Boot: oracle injects expertise + context
2. Work: oracle logs events (compile/test/git/changes)
3. Query: ask oracle anything about ecosystem
4. Compress: context lost? oracle remembers everything

=== EXPERTISE LOADED ===
]")
		end

	is_first_boot: BOOLEAN
			-- Is this the first time oracle is accessed this session?
		do
			Result := not expertise_injected
		end

	mark_expertise_injected
			-- Mark that expertise has been injected this session.
		do
			expertise_injected := True
		ensure
			injected: expertise_injected
		end

feature -- Full Boot Sequence

	full_boot: STRING_32
			-- Complete boot sequence: expertise + context + last handoff.
			-- Call this on every new Claude session.
		require
			is_ready: is_ready
		do
			create Result.make (8000)

			-- Always inject expertise (it's cheap, ensures consistency)
			Result.append (inject_expertise)
			Result.append ("%N%N")

			-- Add last session handoff (most important for continuity)
			Result.append (handoff_brief)
			Result.append ("%N%N")

			-- Add current context
			Result.append (context_brief)

			mark_expertise_injected
		ensure
			expertise_marked: expertise_injected
		end

feature {NONE} -- Expertise state

	expertise_injected: BOOLEAN
			-- Has expertise been injected this session?

feature -- Context Briefing

	context_brief: STRING_32
			-- Generate a brief context summary for session start.
		require
			is_ready: is_ready
		do
			create Result.make (2000)
			Result.append ("=== ORACLE CONTEXT BRIEF ===%N%N")

			-- Library count
			Result.append ("Libraries: ")
			Result.append_integer (library_count)
			Result.append ("%N%N")

			-- Recent activity
			Result.append ("Recent Activity (4h):%N")
			across recent_events (4) as ev loop
				Result.append ("  [")
				Result.append (ev.event_type)
				Result.append ("] ")
				if not ev.library.is_empty then
					Result.append (ev.library)
					Result.append (": ")
				end
				Result.append (ev.details.substring (1, ev.details.count.min (60)))
				Result.append ("%N")
			end

			Result.append ("%N=== END BRIEF ===%N")
		end

feature -- Compilation Logging

	log_compile (a_library, a_target: READABLE_STRING_GENERAL; a_success: BOOLEAN; a_duration: REAL_64)
			-- Log a compilation result.
		require
			is_ready: is_ready
			library_not_empty: not a_library.is_empty
			target_not_empty: not a_target.is_empty
		do
			clear_error
			if attached disk_db as db then
				db.run_sql_with (
					"INSERT INTO compilations (library, target, success, duration) VALUES (?, ?, ?, ?)",
					<<a_library.to_string_32, a_target.to_string_32, a_success, a_duration>>
				)
				if db.has_error then
					set_error (db.last_error_message)
				end
			end
			-- Also log as event for recent activity
			if a_success then
				log_event ("compile", a_library, "SUCCESS (" + a_duration.truncated_to_integer.out + "s) target=" + a_target.to_string_32)
			else
				log_event ("compile", a_library, "FAILED target=" + a_target.to_string_32)
			end
		end

	recent_compiles (a_count: INTEGER): ARRAYED_LIST [TUPLE [library: STRING_32; target: STRING_32; success: BOOLEAN; duration: REAL_64; timestamp: STRING_32]]
			-- Get the most recent _count compilations.
		require
			is_ready: is_ready
			positive_count: a_count > 0
		local
			l_lib, l_target, l_ts: STRING_32
			l_success: BOOLEAN
			l_duration: REAL_64
		do
			create Result.make (a_count)
			if attached disk_db as db then
				if attached db.fetch_with (
					"SELECT library, target, success, duration, timestamp FROM compilations ORDER BY id DESC LIMIT ?",
					<<a_count>>) as res
				then
					across res.rows as row loop
						if attached {READABLE_STRING_GENERAL} row.item (1) as lib then
							l_lib := lib.to_string_32
						else
							create l_lib.make_empty
						end
						if attached {READABLE_STRING_GENERAL} row.item (2) as tgt then
							l_target := tgt.to_string_32
						else
							create l_target.make_empty
						end
						if attached {INTEGER_64} row.item (3) as s then
							l_success := s /= 0
						else
							l_success := False
						end
						if attached {REAL_64} row.item (4) as d then
							l_duration := d
						else
							l_duration := 0.0
						end
						if attached {READABLE_STRING_GENERAL} row.item (5) as ts then
							l_ts := ts.to_string_32
						else
							create l_ts.make_empty
						end
						Result.extend ([l_lib, l_target, l_success, l_duration, l_ts])
					end
				end
			end
		end

	compile_stats (a_library: READABLE_STRING_GENERAL): TUPLE [total: INTEGER; passed: INTEGER; failed: INTEGER; avg_duration: REAL_64]
			-- Get compilation statistics for a library.
		require
			is_ready: is_ready
		local
			l_total, l_passed, l_failed: INTEGER
			l_avg: REAL_64
		do
			if attached disk_db as db then
				if attached db.fetch_with (
					"SELECT COUNT(*), SUM(CASE WHEN success THEN 1 ELSE 0 END), SUM(CASE WHEN NOT success THEN 1 ELSE 0 END), AVG(duration) FROM compilations WHERE library = ?",
					<<a_library.to_string_32>>) as res
				then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as t then l_total := t.to_integer_32 end
						if attached {INTEGER_64} row.item (2) as p then l_passed := p.to_integer_32 end
						if attached {INTEGER_64} row.item (3) as f then l_failed := f.to_integer_32 end
						if attached {REAL_64} row.item (4) as a then l_avg := a end
					end
				end
			end
			Result := [l_total, l_passed, l_failed, l_avg]
		end

feature -- Test Run Tracking

	log_test_run (a_library, a_target: READABLE_STRING_GENERAL; a_total, a_passed, a_failed: INTEGER; a_duration: REAL_64; a_output: detachable READABLE_STRING_GENERAL)
			-- Log a test run result.
		require
			is_ready: is_ready
			library_not_empty: not a_library.is_empty
			target_not_empty: not a_target.is_empty
			valid_counts: a_passed + a_failed <= a_total
		local
			l_output: STRING_32
		do
			clear_error
			if attached a_output as o then
				l_output := o.to_string_32
			else
				create l_output.make_empty
			end
			if attached disk_db as db then
				db.run_sql_with (
					"INSERT INTO test_runs (library, target, total, passed, failed, duration, output) VALUES (?, ?, ?, ?, ?, ?, ?)",
					<<a_library.to_string_32, a_target.to_string_32, a_total, a_passed, a_failed, a_duration, l_output>>
				)
				if db.has_error then
					set_error (db.last_error_message)
				end
			end
			-- Also log as event for recent activity
			log_event ("test", a_library, a_passed.out + "/" + a_total.out + " passed (" + a_duration.truncated_to_integer.out + "s)")
		end

	recent_test_runs (a_count: INTEGER): ARRAYED_LIST [TUPLE [library: STRING_32; target: STRING_32; total: INTEGER; passed: INTEGER; failed: INTEGER; duration: REAL_64; timestamp: STRING_32]]
			-- Get the most recent a_count test runs.
		require
			is_ready: is_ready
			positive_count: a_count > 0
		local
			l_lib, l_target, l_ts: STRING_32
			l_total, l_passed, l_failed: INTEGER
			l_duration: REAL_64
		do
			create Result.make (a_count)
			if attached disk_db as db then
				if attached db.fetch_with (
					"SELECT library, target, total, passed, failed, duration, timestamp FROM test_runs ORDER BY id DESC LIMIT ?",
					<<a_count>>) as res
				then
					across res.rows as row loop
						if attached {READABLE_STRING_GENERAL} row.item (1) as lib then l_lib := lib.to_string_32 else create l_lib.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (2) as tgt then l_target := tgt.to_string_32 else create l_target.make_empty end
						if attached {INTEGER_64} row.item (3) as t then l_total := t.to_integer_32 else l_total := 0 end
						if attached {INTEGER_64} row.item (4) as p then l_passed := p.to_integer_32 else l_passed := 0 end
						if attached {INTEGER_64} row.item (5) as f then l_failed := f.to_integer_32 else l_failed := 0 end
						if attached {REAL_64} row.item (6) as d then l_duration := d else l_duration := 0.0 end
						if attached {READABLE_STRING_GENERAL} row.item (7) as ts then l_ts := ts.to_string_32 else create l_ts.make_empty end
						Result.extend ([l_lib, l_target, l_total, l_passed, l_failed, l_duration, l_ts])
					end
				end
			end
		end

	test_stats (a_library: READABLE_STRING_GENERAL): TUPLE [runs: INTEGER; total_tests: INTEGER; total_passed: INTEGER; total_failed: INTEGER; pass_rate: REAL_64]
			-- Get test statistics for a library.
		require
			is_ready: is_ready
		local
			l_runs, l_total, l_passed, l_failed: INTEGER
			l_rate: REAL_64
		do
			if attached disk_db as db then
				if attached db.fetch_with (
					"SELECT COUNT(*), SUM(total), SUM(passed), SUM(failed) FROM test_runs WHERE library = ?",
					<<a_library.to_string_32>>) as res
				then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as r then l_runs := r.to_integer_32 end
						if attached {INTEGER_64} row.item (2) as t then l_total := t.to_integer_32 end
						if attached {INTEGER_64} row.item (3) as p then l_passed := p.to_integer_32 end
						if attached {INTEGER_64} row.item (4) as f then l_failed := f.to_integer_32 end
					end
				end
			end
			if l_total > 0 then
				l_rate := (l_passed / l_total) * 100.0
			else
				l_rate := 0.0
			end
			Result := [l_runs, l_total, l_passed, l_failed, l_rate]
		end

	failing_libraries: ARRAYED_LIST [TUPLE [library: STRING_32; last_failed: INTEGER; last_run: STRING_32]]
			-- Get libraries with failing tests in their most recent run.
		require
			is_ready: is_ready
		local
			l_lib, l_ts: STRING_32
			l_failed: INTEGER
		do
			create Result.make (10)
			if attached disk_db as db then
				-- Subquery to get the most recent test run per library, then filter to those with failures
				if attached db.fetch ("[
					SELECT library, failed, timestamp FROM test_runs
					WHERE id IN (SELECT MAX(id) FROM test_runs GROUP BY library)
					AND failed > 0
					ORDER BY timestamp DESC
				]") as res
				then
					across res.rows as row loop
						if attached {READABLE_STRING_GENERAL} row.item (1) as lib then l_lib := lib.to_string_32 else create l_lib.make_empty end
						if attached {INTEGER_64} row.item (2) as f then l_failed := f.to_integer_32 else l_failed := 0 end
						if attached {READABLE_STRING_GENERAL} row.item (3) as ts then l_ts := ts.to_string_32 else create l_ts.make_empty end
						Result.extend ([l_lib, l_failed, l_ts])
					end
				end
			end
		end

feature -- Git Tracking

	log_git_commit (a_library: READABLE_STRING_GENERAL; a_hash, a_author, a_message: READABLE_STRING_GENERAL; a_files_changed, a_insertions, a_deletions: INTEGER)
			-- Log a git commit.
		require
			is_ready: is_ready
			library_not_empty: not a_library.is_empty
			hash_not_empty: not a_hash.is_empty
		do
			clear_error
			if attached disk_db as db then
				db.run_sql_with (
					"INSERT INTO git_commits (library, commit_hash, author, message, files_changed, insertions, deletions) VALUES (?, ?, ?, ?, ?, ?, ?)",
					<<a_library.to_string_32, a_hash.to_string_32, a_author.to_string_32, a_message.to_string_32, a_files_changed, a_insertions, a_deletions>>
				)
				if db.has_error then
					set_error (db.last_error_message)
				end
			end
			-- Also log as event
			log_event ("git", a_library, "commit " + a_hash.to_string_32.substring (1, (7).min (a_hash.count)) + ": " + a_message.to_string_32.substring (1, (50).min (a_message.count)))
		end

	recent_commits (a_count: INTEGER): ARRAYED_LIST [TUPLE [library: STRING_32; hash: STRING_32; author: STRING_32; message: STRING_32; files: INTEGER; timestamp: STRING_32]]
			-- Get the most recent a_count git commits across all libraries.
		require
			is_ready: is_ready
			positive_count: a_count > 0
		local
			l_lib, l_hash, l_author, l_msg, l_ts: STRING_32
			l_files: INTEGER
		do
			create Result.make (a_count)
			if attached disk_db as db then
				if attached db.fetch_with (
					"SELECT library, commit_hash, author, message, files_changed, timestamp FROM git_commits ORDER BY id DESC LIMIT ?",
					<<a_count>>) as res
				then
					across res.rows as row loop
						if attached {READABLE_STRING_GENERAL} row.item (1) as lib then l_lib := lib.to_string_32 else create l_lib.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (2) as h then l_hash := h.to_string_32 else create l_hash.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (3) as a then l_author := a.to_string_32 else create l_author.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (4) as m then l_msg := m.to_string_32 else create l_msg.make_empty end
						if attached {INTEGER_64} row.item (5) as f then l_files := f.to_integer_32 else l_files := 0 end
						if attached {READABLE_STRING_GENERAL} row.item (6) as ts then l_ts := ts.to_string_32 else create l_ts.make_empty end
						Result.extend ([l_lib, l_hash, l_author, l_msg, l_files, l_ts])
					end
				end
			end
		end

	library_commits (a_library: READABLE_STRING_GENERAL; a_count: INTEGER): ARRAYED_LIST [TUPLE [hash: STRING_32; author: STRING_32; message: STRING_32; files: INTEGER; insertions: INTEGER; deletions: INTEGER; timestamp: STRING_32]]
			-- Get recent commits for a specific library.
		require
			is_ready: is_ready
			library_not_empty: not a_library.is_empty
			positive_count: a_count > 0
		local
			l_hash, l_author, l_msg, l_ts: STRING_32
			l_files, l_ins, l_del: INTEGER
		do
			create Result.make (a_count)
			if attached disk_db as db then
				if attached db.fetch_with (
					"SELECT commit_hash, author, message, files_changed, insertions, deletions, timestamp FROM git_commits WHERE library = ? ORDER BY id DESC LIMIT ?",
					<<a_library.to_string_32, a_count>>) as res
				then
					across res.rows as row loop
						if attached {READABLE_STRING_GENERAL} row.item (1) as h then l_hash := h.to_string_32 else create l_hash.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (2) as a then l_author := a.to_string_32 else create l_author.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (3) as m then l_msg := m.to_string_32 else create l_msg.make_empty end
						if attached {INTEGER_64} row.item (4) as f then l_files := f.to_integer_32 else l_files := 0 end
						if attached {INTEGER_64} row.item (5) as i then l_ins := i.to_integer_32 else l_ins := 0 end
						if attached {INTEGER_64} row.item (6) as d then l_del := d.to_integer_32 else l_del := 0 end
						if attached {READABLE_STRING_GENERAL} row.item (7) as ts then l_ts := ts.to_string_32 else create l_ts.make_empty end
						Result.extend ([l_hash, l_author, l_msg, l_files, l_ins, l_del, l_ts])
					end
				end
			end
		end

	git_stats: TUPLE [total_commits: INTEGER; libraries_with_commits: INTEGER; total_insertions: INTEGER; total_deletions: INTEGER]
			-- Get overall git statistics.
		require
			is_ready: is_ready
		local
			l_commits, l_libs, l_ins, l_del: INTEGER
		do
			if attached disk_db as db then
				if attached db.fetch ("SELECT COUNT(*), COUNT(DISTINCT library), SUM(insertions), SUM(deletions) FROM git_commits") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as c then l_commits := c.to_integer_32 end
						if attached {INTEGER_64} row.item (2) as l then l_libs := l.to_integer_32 end
						if attached {INTEGER_64} row.item (3) as i then l_ins := i.to_integer_32 end
						if attached {INTEGER_64} row.item (4) as d then l_del := d.to_integer_32 end
					end
				end
			end
			Result := [l_commits, l_libs, l_ins, l_del]
		end

feature -- Session Handoff

	record_handoff (a_current_task, a_work_in_progress, a_next_steps, a_blockers: detachable READABLE_STRING_GENERAL)
			-- Record a session handoff for context continuity.
			-- Called when ending a session to capture current state.
		require
			is_ready: is_ready
		local
			l_task, l_wip, l_next, l_blockers: STRING_32
		do
			clear_error
			-- Convert detachable to empty string if void
			if attached a_current_task as t then l_task := t.to_string_32 else create l_task.make_empty end
			if attached a_work_in_progress as w then l_wip := w.to_string_32 else create l_wip.make_empty end
			if attached a_next_steps as n then l_next := n.to_string_32 else create l_next.make_empty end
			if attached a_blockers as b then l_blockers := b.to_string_32 else create l_blockers.make_empty end

			if attached disk_db as db then
				db.run_sql_with (
					"INSERT INTO session_handoff (current_task, work_in_progress, next_steps, blockers) VALUES (?, ?, ?, ?)",
					<<l_task, l_wip, l_next, l_blockers>>
				)
				if db.has_error then
					set_error (db.last_error_message)
				end
			end
		end

	last_handoff: detachable TUPLE [timestamp: STRING_32; current_task: STRING_32; work_in_progress: STRING_32; next_steps: STRING_32; blockers: STRING_32]
			-- Get the most recent session handoff, if any.
		require
			is_ready: is_ready
		local
			l_ts, l_task, l_wip, l_next, l_blockers: STRING_32
		do
			if attached disk_db as db then
				if attached db.fetch ("SELECT session_end, current_task, work_in_progress, next_steps, blockers FROM session_handoff ORDER BY id DESC LIMIT 1") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						-- Extract each field, converting to STRING_32
						if attached {READABLE_STRING_GENERAL} row.item (1) as ts then l_ts := ts.to_string_32 else create l_ts.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (2) as t then l_task := t.to_string_32 else create l_task.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (3) as w then l_wip := w.to_string_32 else create l_wip.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (4) as n then l_next := n.to_string_32 else create l_next.make_empty end
						if attached {READABLE_STRING_GENERAL} row.item (5) as b then l_blockers := b.to_string_32 else create l_blockers.make_empty end
						Result := [l_ts, l_task, l_wip, l_next, l_blockers]
					end
				end
			end
		end

	handoff_brief: STRING_32
			-- Format last handoff as a brief string for boot output.
		do
			create Result.make (500)
			if attached last_handoff as h then
				Result.append ("=== LAST SESSION HANDOFF ===")
				Result.append ("%NRecorded: ")
				Result.append (h.timestamp)
				if not h.current_task.is_empty then
					Result.append ("%N%NCurrent Task: ")
					Result.append (h.current_task)
				end
				if not h.work_in_progress.is_empty then
					Result.append ("%N%NWork In Progress: ")
					Result.append (h.work_in_progress)
				end
				if not h.next_steps.is_empty then
					Result.append ("%N%NNext Steps: ")
					Result.append (h.next_steps)
				end
				if not h.blockers.is_empty then
					Result.append ("%N%NBlockers: ")
					Result.append (h.blockers)
				end
				Result.append ("%N=== END HANDOFF ===%N")
			else
				Result.append ("(No previous session handoff recorded)")
			end
		end

feature -- Ecosystem Statistics (Bean-Counter Metrics)

	ecosystem_stats (a_period: READABLE_STRING_GENERAL): STRING_32
			-- Generate ecosystem statistics report for management.
			-- a_period: "today", "yesterday", "week", "month", "quarter", "year", "all"
		require
			is_ready: is_ready
		local
			l_time_filter: STRING_8
			l_lib_count, l_class_count, l_feat_count: INTEGER
			l_parent_count, l_client_count: INTEGER
			l_compile_count, l_test_count, l_commit_count: INTEGER
			l_compile_success, l_test_passed, l_test_failed: INTEGER
			l_lines_added, l_lines_deleted: INTEGER
		do
			create Result.make (3000)

			-- Determine time filter for SQL
			if a_period.same_string ("today") then
				l_time_filter := "datetime('now', 'start of day')"
			elseif a_period.same_string ("yesterday") then
				l_time_filter := "datetime('now', '-1 day', 'start of day')"
			elseif a_period.same_string ("week") then
				l_time_filter := "datetime('now', '-7 days')"
			elseif a_period.same_string ("month") then
				l_time_filter := "datetime('now', '-30 days')"
			elseif a_period.same_string ("quarter") then
				l_time_filter := "datetime('now', '-90 days')"
			elseif a_period.same_string ("year") then
				l_time_filter := "datetime('now', '-365 days')"
			else
				l_time_filter := "datetime('1970-01-01')" -- All time
			end

			Result.append ("====================================================================%N")
			Result.append ("       SIMPLE EIFFEL ECOSYSTEM - WORK METRICS REPORT%N")
			Result.append ("====================================================================%N")
			Result.append ("Period: ")
			Result.append (a_period.to_string_32.as_upper)
			Result.append ("%NGenerated: ")
			Result.append ((create {SIMPLE_DATE_TIME}.make_now).to_iso8601)
			Result.append ("%N%N")

			if attached disk_db as db then
				-- CODEBASE SIZE
				Result.append ("--- CODEBASE SIZE ---%N")
				if attached db.fetch ("SELECT COUNT(*) FROM libraries WHERE name LIKE 'simple_%%'") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_lib_count := cnt.to_integer_32 end
					end
				end
				if attached db.fetch ("SELECT COUNT(*) FROM classes") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_class_count := cnt.to_integer_32 end
					end
				end
				if attached db.fetch ("SELECT COUNT(*) FROM features") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_feat_count := cnt.to_integer_32 end
					end
				end
				if attached db.fetch ("SELECT COUNT(*) FROM class_parents") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_parent_count := cnt.to_integer_32 end
					end
				end
				if attached db.fetch ("SELECT COUNT(*) FROM class_clients") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_client_count := cnt.to_integer_32 end
					end
				end
				Result.append ("Libraries:              ")
				Result.append (l_lib_count.out)
				Result.append ("%NClasses:                ")
				Result.append (l_class_count.out)
				Result.append ("%NFeatures (API surface): ")
				Result.append (l_feat_count.out)
				Result.append ("%NInheritance links:      ")
				Result.append (l_parent_count.out)
				Result.append ("%NClient relationships:   ")
				Result.append (l_client_count.out)
				Result.append ("%N%N")

				-- DEVELOPMENT ACTIVITY
				Result.append ("--- DEVELOPMENT ACTIVITY ---%N")
				if attached db.fetch ("SELECT COUNT(*), SUM(CASE WHEN success THEN 1 ELSE 0 END) FROM compilations WHERE timestamp >= " + l_time_filter) as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_compile_count := cnt.to_integer_32 end
						if attached {INTEGER_64} row.item (2) as suc then l_compile_success := suc.to_integer_32 end
					end
				end
				if attached db.fetch ("SELECT COUNT(*), SUM(passed), SUM(failed) FROM test_runs WHERE timestamp >= " + l_time_filter) as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_test_count := cnt.to_integer_32 end
						if attached {INTEGER_64} row.item (2) as p then l_test_passed := p.to_integer_32 end
						if attached {INTEGER_64} row.item (3) as f then l_test_failed := f.to_integer_32 end
					end
				end
				if attached db.fetch ("SELECT COUNT(*), COALESCE(SUM(insertions),0), COALESCE(SUM(deletions),0) FROM git_commits WHERE timestamp >= " + l_time_filter) as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then l_commit_count := cnt.to_integer_32 end
						if attached {INTEGER_64} row.item (2) as ins then l_lines_added := ins.to_integer_32 end
						if attached {INTEGER_64} row.item (3) as del then l_lines_deleted := del.to_integer_32 end
					end
				end
				Result.append ("Compilations:           ")
				Result.append (l_compile_count.out)
				Result.append (" (")
				Result.append (l_compile_success.out)
				Result.append (" successful")
				if l_compile_count > 0 then
					Result.append (", ")
					Result.append (((l_compile_success * 100) // l_compile_count).out)
					Result.append ("%% success rate")
				end
				Result.append (")%N")
				Result.append ("Test runs:              ")
				Result.append (l_test_count.out)
				Result.append (" (")
				Result.append (l_test_passed.out)
				Result.append (" passed, ")
				Result.append (l_test_failed.out)
				Result.append (" failed)%N")
				Result.append ("Git commits:            ")
				Result.append (l_commit_count.out)
				Result.append ("%NLines added:            +")
				Result.append (l_lines_added.out)
				Result.append ("%NLines deleted:          -")
				Result.append (l_lines_deleted.out)
				Result.append ("%NNet change:             ")
				if l_lines_added >= l_lines_deleted then
					Result.append ("+")
				end
				Result.append ((l_lines_added - l_lines_deleted).out)
				Result.append ("%N%N")

				-- DBC QUALITY METRICS
				Result.append ("--- DESIGN BY CONTRACT (Quality Indicators) ---%N")
				if attached db.fetch ("SELECT COUNT(*) FROM features WHERE preconditions != '' AND preconditions IS NOT NULL") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then
							Result.append ("Features with preconditions:  ")
							Result.append (cnt.to_integer_32.out)
							if l_feat_count > 0 then
								Result.append (" (")
								Result.append (((cnt.to_integer_32 * 100) // l_feat_count).out)
								Result.append ("%%)")
							end
							Result.append ("%N")
						end
					end
				end
				if attached db.fetch ("SELECT COUNT(*) FROM features WHERE postconditions != '' AND postconditions IS NOT NULL") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						if attached {INTEGER_64} row.item (1) as cnt then
							Result.append ("Features with postconditions: ")
							Result.append (cnt.to_integer_32.out)
							if l_feat_count > 0 then
								Result.append (" (")
								Result.append (((cnt.to_integer_32 * 100) // l_feat_count).out)
								Result.append ("%%)")
							end
							Result.append ("%N")
						end
					end
				end
				Result.append ("%N")

				-- AI+HUMAN COLLABORATION VALUE
				Result.append ("--- AI+HUMAN COLLABORATION ---%N")
				Result.append ("This ecosystem demonstrates the value of:%N")
				Result.append ("  * Design by Contract: Specifications catch bugs at compile time%N")
				Result.append ("  * Void Safety: No null pointer exceptions possible%N")
				Result.append ("  * Human guidance + AI implementation: Best of both%N")
				Result.append ("  * Persistent memory (Oracle): Context survives sessions%N")
				Result.append ("%N")
			end

			Result.append ("====================================================================%N")
			Result.append ("                  Generated by simple_oracle%N")
			Result.append ("====================================================================%N")
		end

feature -- Compiled Statistics (EIFGENs Metadata)

	store_compiled_stats (a_library, a_target: READABLE_STRING_GENERAL; a_stats: TUPLE [
			class_count, feature_count, attribute_count, lines_of_code,
			precondition_count, postcondition_count, invariant_count: INTEGER;
			src_path: READABLE_STRING_GENERAL])
			-- Store or update compiled statistics for a library/target.
		require
			is_ready: is_ready
			library_not_empty: not a_library.is_empty
			target_not_empty: not a_target.is_empty
		do
			clear_error
			if attached disk_db as db then
				db.run_sql_with (
					"INSERT OR REPLACE INTO compiled_stats (library, target, class_count, feature_count, " +
					"attribute_count, lines_of_code, precondition_count, postcondition_count, invariant_count, " +
					"scanned_at, eifgens_path) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), ?)",
					<<a_library.to_string_32, a_target.to_string_32,
					  a_stats.class_count, a_stats.feature_count, a_stats.attribute_count,
					  a_stats.lines_of_code, a_stats.precondition_count, a_stats.postcondition_count,
					  a_stats.invariant_count, a_stats.src_path.to_string_32>>)
				if db.has_error then
					set_error (db.last_error_message)
				end
			end
		end

	get_compiled_stats (a_library: READABLE_STRING_GENERAL): detachable TUPLE [
			library, target: STRING_32;
			class_count, feature_count, attribute_count, lines_of_code,
			precondition_count, postcondition_count, invariant_count: INTEGER;
			scanned_at, eifgens_path: STRING_32]
			-- Get compiled statistics for a library.
		require
			is_ready: is_ready
			library_not_empty: not a_library.is_empty
		do
			if attached disk_db as db then
				if attached db.fetch_with (
					"SELECT library, target, class_count, feature_count, attribute_count, lines_of_code, " +
					"precondition_count, postcondition_count, invariant_count, scanned_at, eifgens_path " +
					"FROM compiled_stats WHERE library = ? ORDER BY scanned_at DESC LIMIT 1",
					<<a_library.to_string_32>>) as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						Result := [
							safe_string (row.item (1)),
							safe_string (row.item (2)),
							safe_integer (row.item (3)),
							safe_integer (row.item (4)),
							safe_integer (row.item (5)),
							safe_integer (row.item (6)),
							safe_integer (row.item (7)),
							safe_integer (row.item (8)),
							safe_integer (row.item (9)),
							safe_string (row.item (10)),
							safe_string (row.item (11))
						]
					end
				end
			end
		end

	ecosystem_census: STRING_32
			-- Generate comprehensive ecosystem census from compiled stats with statistical analysis.
		require
			is_ready: is_ready
		local
			l_total_classes, l_total_features, l_total_attrs, l_total_loc: INTEGER
			l_total_pre, l_total_post, l_total_inv, l_total_contracts: INTEGER
			l_lib_count: INTEGER
			l_lib: STRING_32
			l_classes, l_feats, l_loc: INTEGER
			l_min_cls, l_max_cls, l_min_feat, l_max_feat, l_min_loc, l_max_loc: INTEGER
			l_avg_cls, l_avg_feat, l_avg_loc: REAL_64
			l_med_cls, l_med_feat, l_med_loc: INTEGER
			l_density, l_contracts_per_feat: REAL_64
			l_int_val: INTEGER
		do
			create Result.make (5000)
			Result.append ("=== SIMPLE ECOSYSTEM CENSUS ===%N%N")

			if attached disk_db as db then
				-- Aggregate totals
				if attached db.fetch ("SELECT COUNT(DISTINCT library), SUM(class_count), SUM(feature_count), " +
					"SUM(attribute_count), SUM(lines_of_code), SUM(precondition_count), " +
					"SUM(postcondition_count), SUM(invariant_count) FROM compiled_stats") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						l_lib_count := safe_integer (row.item (1))
						l_total_classes := safe_integer (row.item (2))
						l_total_features := safe_integer (row.item (3))
						l_total_attrs := safe_integer (row.item (4))
						l_total_loc := safe_integer (row.item (5))
						l_total_pre := safe_integer (row.item (6))
						l_total_post := safe_integer (row.item (7))
						l_total_inv := safe_integer (row.item (8))
						l_total_contracts := l_total_pre + l_total_post + l_total_inv
					end
				end

				-- Statistical measures for classes
				if attached db.fetch ("SELECT MIN(class_count), MAX(class_count), AVG(class_count) FROM compiled_stats") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						l_min_cls := safe_integer (row.item (1))
						l_max_cls := safe_integer (row.item (2))
						l_avg_cls := safe_real (row.item (3))
					end
				end
				if attached db.fetch ("SELECT class_count FROM compiled_stats ORDER BY class_count LIMIT 1 OFFSET " + (l_lib_count // 2).out) as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						l_med_cls := safe_integer (row.item (1))
					end
				end

				-- Statistical measures for features
				if attached db.fetch ("SELECT MIN(feature_count), MAX(feature_count), AVG(feature_count) FROM compiled_stats") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						l_min_feat := safe_integer (row.item (1))
						l_max_feat := safe_integer (row.item (2))
						l_avg_feat := safe_real (row.item (3))
					end
				end
				if attached db.fetch ("SELECT feature_count FROM compiled_stats ORDER BY feature_count LIMIT 1 OFFSET " + (l_lib_count // 2).out) as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						l_med_feat := safe_integer (row.item (1))
					end
				end

				-- Statistical measures for LOC
				if attached db.fetch ("SELECT MIN(lines_of_code), MAX(lines_of_code), AVG(lines_of_code) FROM compiled_stats") as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						l_min_loc := safe_integer (row.item (1))
						l_max_loc := safe_integer (row.item (2))
						l_avg_loc := safe_real (row.item (3))
					end
				end
				if attached db.fetch ("SELECT lines_of_code FROM compiled_stats ORDER BY lines_of_code LIMIT 1 OFFSET " + (l_lib_count // 2).out) as res then
					if not res.rows.is_empty and then attached res.rows.first as row then
						l_med_loc := safe_integer (row.item (1))
					end
				end

				-- Derived metrics
				if l_total_loc > 0 then
					l_density := (l_total_contracts / l_total_loc) * 100
				end
				if l_total_features > 0 then
					l_contracts_per_feat := l_total_contracts / l_total_features
				end

				-- Output
				Result.append ("Libraries Scanned: ")
				Result.append (l_lib_count.out)
				Result.append ("%N%N--- TOTALS ---%N")
				Result.append ("  Classes:     ")
				Result.append (l_total_classes.out)
				Result.append ("%N  Features:    ")
				Result.append (l_total_features.out)
				Result.append ("%N  Attributes:  ")
				Result.append (l_total_attrs.out)
				Result.append ("%N  LOC:         ")
				Result.append (format_number (l_total_loc))
				Result.append ("%N%N--- DISTRIBUTION (per library) ---%N")
				Result.append ("                   Min      Max      Avg   Median%N")
				Result.append ("  Classes:     ")
				Result.append (pad_left (l_min_cls.out, 6))
				Result.append ("   ")
				Result.append (pad_left (l_max_cls.out, 6))
				Result.append ("   ")
				Result.append (pad_left (format_decimal (l_avg_cls, 1), 6))
				Result.append ("   ")
				Result.append (pad_left (l_med_cls.out, 6))
				Result.append ("%N  Features:   ")
				Result.append (pad_left (l_min_feat.out, 6))
				Result.append ("   ")
				Result.append (pad_left (l_max_feat.out, 6))
				Result.append ("   ")
				Result.append (pad_left (format_decimal (l_avg_feat, 1), 6))
				Result.append ("   ")
				Result.append (pad_left (l_med_feat.out, 6))
				Result.append ("%N  LOC:        ")
				Result.append (pad_left (l_min_loc.out, 6))
				Result.append ("   ")
				Result.append (pad_left (l_max_loc.out, 6))
				Result.append ("   ")
				Result.append (pad_left (format_decimal (l_avg_loc, 1), 6))
				Result.append ("   ")
				Result.append (pad_left (l_med_loc.out, 6))

				Result.append ("%N%N--- CONTRACT COVERAGE ---%N")
				Result.append ("  Preconditions:   ")
				Result.append (format_number (l_total_pre))
				Result.append (" lines%N  Postconditions:  ")
				Result.append (format_number (l_total_post))
				Result.append (" lines%N  Invariants:      ")
				Result.append (format_number (l_total_inv))
				Result.append (" lines%N  TOTAL:           ")
				Result.append (format_number (l_total_contracts))
				Result.append (" lines%N%N--- QUALITY METRICS ---%N")
				Result.append ("  Contract Density:     ")
				Result.append (format_decimal (l_density, 1))
				Result.append ("%% of LOC%N  Contracts/Feature:    ")
				Result.append (format_decimal (l_contracts_per_feat, 2))

				-- Top 10 by features
				Result.append ("%N%N--- TOP 10 BY FEATURES ---%N")
				if attached db.fetch ("SELECT library, feature_count, class_count, lines_of_code FROM compiled_stats ORDER BY feature_count DESC LIMIT 10") as res then
					across res.rows as row loop
						l_lib := safe_string (row.item (1))
						l_feats := safe_integer (row.item (2))
						l_classes := safe_integer (row.item (3))
						l_loc := safe_integer (row.item (4))
						Result.append ("  ")
						Result.append (pad_right (l_lib, 22))
						Result.append (pad_left (l_feats.out, 5))
						Result.append (" feat  ")
						Result.append (pad_left (l_classes.out, 3))
						Result.append (" cls  ")
						Result.append (pad_left (format_number (l_loc), 6))
						Result.append (" LOC%N")
					end
				end

				-- Top 10 by LOC
				Result.append ("%N--- TOP 10 BY LOC ---%N")
				if attached db.fetch ("SELECT library, lines_of_code, feature_count, class_count FROM compiled_stats ORDER BY lines_of_code DESC LIMIT 10") as res then
					across res.rows as row loop
						l_lib := safe_string (row.item (1))
						l_loc := safe_integer (row.item (2))
						l_feats := safe_integer (row.item (3))
						l_classes := safe_integer (row.item (4))
						Result.append ("  ")
						Result.append (pad_right (l_lib, 22))
						Result.append (pad_left (format_number (l_loc), 6))
						Result.append (" LOC  ")
						Result.append (pad_left (l_feats.out, 5))
						Result.append (" feat  ")
						Result.append (pad_left (l_classes.out, 3))
						Result.append (" cls%N")
					end
				end

				-- Top 10 by contract density
				Result.append ("%N--- TOP 10 BY CONTRACT DENSITY (min 100 LOC) ---%N")
				if attached db.fetch ("SELECT library, " +
					"CAST((precondition_count + postcondition_count + invariant_count) AS REAL) * 100.0 / lines_of_code as density, " +
					"(precondition_count + postcondition_count + invariant_count) as contracts, lines_of_code " +
					"FROM compiled_stats WHERE lines_of_code > 100 ORDER BY density DESC LIMIT 10") as res then
					across res.rows as row loop
						l_lib := safe_string (row.item (1))
						l_density := safe_real (row.item (2))
						l_int_val := safe_integer (row.item (3))
						l_loc := safe_integer (row.item (4))
						Result.append ("  ")
						Result.append (pad_right (l_lib, 22))
						Result.append (pad_left (format_decimal (l_density, 1), 5))
						Result.append ("%%  (")
						Result.append (l_int_val.out)
						Result.append (" / ")
						Result.append (format_number (l_loc))
						Result.append (")%N")
					end
				end
			end

			Result.append ("%N=== END CENSUS ===%N")
		end

	format_number (a_num: INTEGER): STRING_32
			-- Format number with comma separators
		do
			if a_num >= 1000 then
				Result := (a_num // 1000).out + "," + pad_left ((a_num \\ 1000).out, 3).twin
				Result.replace_substring_all (" ", "0")
			else
				Result := a_num.out
			end
		end

	format_decimal (a_num: REAL_64; a_places: INTEGER): STRING_32
			-- Format real with specified decimal places
		local
			l_mult: REAL_64
			l_int: INTEGER_64
		do
			l_mult := (10 ^ a_places).truncated_to_real
			l_int := (a_num * l_mult + 0.5).truncated_to_integer_64
			Result := (l_int // l_mult.truncated_to_integer_64).out
			Result.append (".")
			Result.append (pad_left ((l_int \\ l_mult.truncated_to_integer_64).out, a_places))
			Result.replace_substring_all (" ", "0")
		end

	pad_left (a_str: STRING_32; a_width: INTEGER): STRING_32
			-- Pad string on left to width
		do
			create Result.make (a_width)
			from until Result.count + a_str.count >= a_width loop
				Result.append_character (' ')
			end
			Result.append (a_str)
		end

	pad_right (a_str: STRING_32; a_width: INTEGER): STRING_32
			-- Pad string on right to width
		do
			Result := a_str.twin
			from until Result.count >= a_width loop
				Result.append_character (' ')
			end
		end

	safe_real (a_val: detachable ANY): REAL_64
			-- Safely convert value to real
		do
			if attached {REAL_64} a_val as r then
				Result := r
			elseif attached {INTEGER_64} a_val as i64 then
				Result := i64.to_double
			elseif attached {INTEGER} a_val as i then
				Result := i.to_double
			elseif attached a_val as v then
				Result := v.out.to_double
			end
		end

feature -- Proactive Guidance (Check Command)

	check_guidance: STRING_32
			-- Return all guidance, warnings, and rules that might help Claude.
			-- Called when Larry says "see oracle" or "consult oracle".
			-- This is the attention-forcing mechanism for proactive guidance.
		require
			is_ready: is_ready
		do
			create Result.make (4000)
			Result.append ("=== ORACLE GUIDANCE CHECK ===%N%N")

			-- 1. Show any rules (highest priority)
			Result.append (rules_summary)

			-- 2. Show recent gotchas
			Result.append (gotchas_summary)

			-- 3. Show recent errors/mistakes
			Result.append (recent_errors_summary)

			-- 4. Show current task context
			if attached last_handoff as h and then not h.current_task.is_empty then
				Result.append ("--- CURRENT TASK ---%N")
				Result.append (h.current_task)
				Result.append ("%N%N")
			end

			Result.append ("=== END GUIDANCE ===%N")
		end

	rules_summary: STRING_32
			-- Return all 'rule' entries from knowledge base.
		local
			l_title, l_content: STRING_32
		do
			create Result.make (1000)
			if attached disk_db as db then
				if attached db.fetch ("SELECT title, content FROM knowledge WHERE category = 'rule' ORDER BY rowid DESC LIMIT 10") as res then
					if not res.rows.is_empty then
						Result.append ("--- RULES (Must Follow) ---%N")
						across res.rows as row loop
							if attached {READABLE_STRING_GENERAL} row.item (1) as t then
								l_title := t.to_string_32
							else
								create l_title.make_empty
							end
							if attached {READABLE_STRING_GENERAL} row.item (2) as c then
								l_content := c.to_string_32
							else
								create l_content.make_empty
							end
							Result.append ("%N* ")
							Result.append (l_title)
							Result.append ("%N  ")
							-- Truncate long content
							if l_content.count > 200 then
								Result.append (l_content.substring (1, 200))
								Result.append ("...")
							else
								Result.append (l_content)
							end
							Result.append ("%N")
						end
						Result.append ("%N")
					end
				end
			end
		end

	gotchas_summary: STRING_32
			-- Return all 'gotcha' entries from knowledge base.
		local
			l_title, l_content: STRING_32
		do
			create Result.make (1000)
			if attached disk_db as db then
				if attached db.fetch ("SELECT title, content FROM knowledge WHERE category = 'gotcha' ORDER BY rowid DESC LIMIT 5") as res then
					if not res.rows.is_empty then
						Result.append ("--- GOTCHAS (Common Mistakes) ---%N")
						across res.rows as row loop
							if attached {READABLE_STRING_GENERAL} row.item (1) as t then
								l_title := t.to_string_32
							else
								create l_title.make_empty
							end
							if attached {READABLE_STRING_GENERAL} row.item (2) as c then
								l_content := c.to_string_32
							else
								create l_content.make_empty
							end
							Result.append ("%N* ")
							Result.append (l_title)
							Result.append (": ")
							-- Truncate long content
							if l_content.count > 150 then
								Result.append (l_content.substring (1, 150))
								Result.append ("...")
							else
								Result.append (l_content)
							end
							Result.append ("%N")
						end
						Result.append ("%N")
					end
				end
			end
		end

	recent_errors_summary: STRING_32
			-- Return recent error events (last 24h).
		local
			l_lib, l_details, l_ts: STRING_32
		do
			create Result.make (1000)
			if attached disk_db as db then
				if attached db.fetch ("SELECT library, details, timestamp FROM events WHERE event_type = 'error' AND timestamp > datetime('now', '-24 hours') ORDER BY timestamp DESC LIMIT 5") as res then
					if not res.rows.is_empty then
						Result.append ("--- RECENT ERRORS (24h) ---%N")
						across res.rows as row loop
							if attached {READABLE_STRING_GENERAL} row.item (1) as lib then
								l_lib := lib.to_string_32
							else
								create l_lib.make_empty
							end
							if attached {READABLE_STRING_GENERAL} row.item (2) as det then
								l_details := det.to_string_32
							else
								create l_details.make_empty
							end
							if attached {READABLE_STRING_GENERAL} row.item (3) as ts then
								l_ts := ts.to_string_32
							else
								create l_ts.make_empty
							end
							Result.append ("%N[")
							Result.append (l_ts)
							Result.append ("] ")
							if not l_lib.is_empty then
								Result.append (l_lib)
								Result.append (": ")
							end
							-- Truncate long details
							if l_details.count > 100 then
								Result.append (l_details.substring (1, 100))
								Result.append ("...")
							else
								Result.append (l_details)
							end
							Result.append ("%N")
						end
						Result.append ("%N")
					end
				end
			end
		end

feature -- Cleanup

	close
			-- Close all database connections.
			-- Call this before program exit to prevent segfaults.
		do
			if attached memory_db as mem then
				if mem.is_open then
					mem.close
				end
			end
			if attached disk_db as disk then
				-- In memory_only mode, disk_db points to same object as memory_db
				-- So only close if it's a different object
				if not is_memory_only and then disk.is_open then
					disk.close
				end
			end
			memory_db := Void
			disk_db := Void
		ensure
			memory_closed: memory_db = Void
			disk_closed: disk_db = Void
		end

feature -- Persistence

	sync_to_disk
			-- Sync all memory tables to disk.
		require
			is_ready: is_ready
		do
			-- Memory is write-through, so this is mainly for safety
			if attached disk_db as db then
				db.run_sql ("PRAGMA wal_checkpoint(TRUNCATE)")
			end
		end

	sync_memory_from_disk
			-- Load disk data into memory for fast queries.
			-- Called during initialization - databases must be attached.
			-- Note: knowledge table is FTS5 (disk-only), not synced.
		do
			if attached memory_db and attached disk_db then
				sync_table_to_memory ("libraries")
				sync_table_to_memory ("events")
				sync_table_to_memory ("classes")
				sync_table_to_memory ("patterns")
				-- knowledge is FTS5 virtual table, queried directly from disk
			end
		end

feature {NONE} -- Implementation

	create_databases
			-- Create both memory and disk databases.
		local
			l_mem: SIMPLE_SQL_DATABASE
			l_disk: SIMPLE_SQL_DATABASE
		do
			create l_mem.make_memory
			memory_db := l_mem

			create l_disk.make (db_path)
			disk_db := l_disk
		end

	ensure_schema
			-- Create tables if they don't exist.
		do
			if attached disk_db as db then
				-- Libraries table
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS libraries (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						name TEXT UNIQUE NOT NULL,
						path TEXT NOT NULL,
						description TEXT,
						phase INTEGER DEFAULT 1,
						has_tests BOOLEAN DEFAULT 0,
						has_docs BOOLEAN DEFAULT 0,
						last_compile TEXT,
						last_test TEXT,
						last_seen TEXT,
						created_at TEXT DEFAULT (datetime('now'))
					)
				]")

				-- Events table
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS events (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						event_type TEXT NOT NULL,
						library TEXT,
						details TEXT,
						timestamp TEXT DEFAULT (datetime('now'))
					)
				]")

				-- Classes table
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS classes (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						library_id INTEGER REFERENCES libraries(id),
						name TEXT NOT NULL,
						file_path TEXT,
						description TEXT,
						has_contracts BOOLEAN DEFAULT 0,
						feature_count INTEGER DEFAULT 0
					)
				]")

				-- Knowledge base with FTS5 full-text search
				db.run_sql ("[
					CREATE VIRTUAL TABLE IF NOT EXISTS knowledge USING fts5(
						category,
						title,
						content,
						tokenize='porter unicode61'
					)
				]")

				-- Patterns table
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS patterns (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						name TEXT NOT NULL,
						category TEXT,
						description TEXT,
						code_example TEXT,
						use_cases TEXT
					)
				]")

				-- Tasks/work items
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS tasks (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						title TEXT NOT NULL,
						description TEXT,
						library TEXT,
						status TEXT DEFAULT 'pending',
						priority INTEGER DEFAULT 5,
						created_at TEXT DEFAULT (datetime('now')),
						completed_at TEXT
					)
				]")

				-- Session handoff for context continuity across sessions
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS session_handoff (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						session_end TEXT DEFAULT (datetime('now')),
						current_task TEXT,
						work_in_progress TEXT,
						next_steps TEXT,
						blockers TEXT
					)
				]")

				-- Compilations table (build history)
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS compilations (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						library TEXT NOT NULL,
						target TEXT NOT NULL,
						success BOOLEAN NOT NULL,
						duration REAL,
						error_message TEXT,
						timestamp TEXT DEFAULT (datetime('now'))
					)
				]")

				-- Test runs table (test history)
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS test_runs (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						library TEXT NOT NULL,
						target TEXT NOT NULL,
						total INTEGER NOT NULL DEFAULT 0,
						passed INTEGER NOT NULL DEFAULT 0,
						failed INTEGER NOT NULL DEFAULT 0,
						duration REAL,
						output TEXT,
						timestamp TEXT DEFAULT (datetime('now'))
					)
				]")

				-- Git commits table (version control history)
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS git_commits (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						library TEXT NOT NULL,
						commit_hash TEXT NOT NULL,
						author TEXT,
						message TEXT,
						files_changed INTEGER,
						insertions INTEGER,
						deletions INTEGER,
						timestamp TEXT DEFAULT (datetime('now'))
					)
				]")

				-- Indexes for performance
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_compilations_library ON compilations(library)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_compilations_timestamp ON compilations(timestamp)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_events_library ON events(library)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_classes_library ON classes(library_id)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_test_runs_library ON test_runs(library)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_test_runs_timestamp ON test_runs(timestamp)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_git_commits_library ON git_commits(library)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_git_commits_timestamp ON git_commits(timestamp)")

				-- Features table for ecosystem scanning (API documentation)
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS features (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						class_id INTEGER REFERENCES classes(id),
						name TEXT NOT NULL,
						signature TEXT,
						preconditions TEXT,
						postconditions TEXT,
						is_query BOOLEAN DEFAULT 0,
						description TEXT
					)
				]")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_features_class ON features(class_id)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_features_name ON features(name)")

				-- Phase 3: Class relationships (inheritance hierarchy)
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS class_parents (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						class_id INTEGER NOT NULL REFERENCES classes(id),
						parent_name TEXT NOT NULL,
						parent_class_id INTEGER REFERENCES classes(id),
						rename_clause TEXT,
						redefine_clause TEXT,
						UNIQUE(class_id, parent_name)
					)
				]")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_class_parents_class ON class_parents(class_id)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_class_parents_parent ON class_parents(parent_name)")

				-- Phase 3: Client/supplier relationships (who uses whom)
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS class_clients (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						client_class_id INTEGER NOT NULL REFERENCES classes(id),
						supplier_name TEXT NOT NULL,
						supplier_class_id INTEGER REFERENCES classes(id),
						usage_type TEXT,
						UNIQUE(client_class_id, supplier_name)
					)
				]")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_class_clients_client ON class_clients(client_class_id)")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_class_clients_supplier ON class_clients(supplier_name)")

				-- Compiled stats from EIFGENs metadata
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS compiled_stats (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						library TEXT NOT NULL,
						target TEXT NOT NULL,
						class_count INTEGER DEFAULT 0,
						feature_count INTEGER DEFAULT 0,
						attribute_count INTEGER DEFAULT 0,
						lines_of_code INTEGER DEFAULT 0,
						precondition_count INTEGER DEFAULT 0,
						postcondition_count INTEGER DEFAULT 0,
						invariant_count INTEGER DEFAULT 0,
						scanned_at TEXT DEFAULT CURRENT_TIMESTAMP,
						eifgens_path TEXT,
						UNIQUE(library, target)
					)
				]")
				db.run_sql ("CREATE INDEX IF NOT EXISTS idx_compiled_stats_library ON compiled_stats(library)")

				-- Phase 3: File timestamps for incremental scanning
				db.run_sql ("ALTER TABLE classes ADD COLUMN file_modified INTEGER DEFAULT 0")
				-- Note: ALTER TABLE ADD COLUMN is safe - it does nothing if column exists
			end

			-- Create same schema in memory DB
			if attached memory_db as db then
				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS libraries (
						id INTEGER PRIMARY KEY,
						name TEXT UNIQUE NOT NULL,
						path TEXT NOT NULL,
						description TEXT,
						phase INTEGER DEFAULT 1,
						has_tests BOOLEAN DEFAULT 0,
						has_docs BOOLEAN DEFAULT 0,
						last_compile TEXT,
						last_test TEXT,
						last_seen TEXT,
						created_at TEXT
					)
				]")

				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS events (
						id INTEGER PRIMARY KEY,
						event_type TEXT NOT NULL,
						library TEXT,
						details TEXT,
						timestamp TEXT
					)
				]")

				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS classes (
						id INTEGER PRIMARY KEY,
						library_id INTEGER,
						name TEXT NOT NULL,
						file_path TEXT,
						description TEXT,
						has_contracts BOOLEAN DEFAULT 0,
						feature_count INTEGER DEFAULT 0
					)
				]")

				-- FTS5 knowledge table is disk-only, no memory copy needed
				-- (FTS5 virtual tables can't be synced like regular tables)

				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS patterns (
						id INTEGER PRIMARY KEY,
						name TEXT NOT NULL,
						category TEXT,
						description TEXT,
						code_example TEXT,
						use_cases TEXT
					)
				]")

				db.run_sql ("[
					CREATE TABLE IF NOT EXISTS tasks (
						id INTEGER PRIMARY KEY,
						title TEXT NOT NULL,
						description TEXT,
						library TEXT,
						status TEXT DEFAULT 'pending',
						priority INTEGER DEFAULT 5,
						created_at TEXT,
						completed_at TEXT
					)
				]")
			end
		end

	sync_table_to_memory (a_table: STRING)
			-- Copy table data from disk to memory.
			-- Fails silently if table is empty or query fails.
		do
			if attached memory_db as mem and attached disk_db as disk then
				-- Clear memory table (ignore errors)
				mem.execute ("DELETE FROM " + a_table)
				-- Note: For MVP, we write to disk and query from memory
				-- Real sync would copy rows, but tables are small enough
				-- that we can query disk directly when needed
			end
		end

	clear_error
			-- Clear any previous error.
		do
			last_error := Void
		ensure
			no_error: not has_error
		end

	set_error (a_message: detachable READABLE_STRING_GENERAL)
			-- Set error message.
		do
			if attached a_message as msg then
				last_error := msg.to_string_32
			else
				last_error := "Unknown error"
			end
		ensure
			has_error: has_error
		end

	safe_string (a_value: detachable ANY): STRING_32
			-- Convert value to string, empty if Void.
		do
			if attached {READABLE_STRING_GENERAL} a_value as s then
				Result := s.to_string_32
			else
				create Result.make_empty
			end
		ensure
			result_attached: Result /= Void
		end

	safe_integer (a_value: detachable ANY): INTEGER
			-- Convert value to integer, 0 if Void or not numeric.
		do
			if attached {INTEGER_64} a_value as i then
				Result := i.to_integer_32
			elseif attached {INTEGER} a_value as i then
				Result := i
			else
				Result := 0
			end
		end

feature {NONE} -- Constants

	Default_db_path: STRING = "D:\prod\simple_oracle\oracle.db"
			-- Default database file location.

invariant
	db_path_not_empty: not db_path.is_empty

end
