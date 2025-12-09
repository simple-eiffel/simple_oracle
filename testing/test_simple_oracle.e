note
	description: "Tests for SIMPLE_ORACLE"
	date: "$Date$"
	revision: "$Revision$"
	testing: "type/manual"

class
	TEST_SIMPLE_ORACLE

inherit
	EQA_TEST_SET
		redefine
			on_prepare,
			on_clean
		end

feature {NONE} -- Preparation

	on_prepare
			-- Setup test environment.
		do
			-- Use a test-specific database path
			test_db_path := "test_oracle.db"
			-- Clean up any leftover test db
			if (create {RAW_FILE}.make_with_name (test_db_path)).exists then
				(create {RAW_FILE}.make_with_name (test_db_path)).delete
			end
		end

	on_clean
			-- Cleanup after tests.
		do
			-- Remove test database
			if (create {RAW_FILE}.make_with_name (test_db_path)).exists then
				(create {RAW_FILE}.make_with_name (test_db_path)).delete
			end
		end

feature -- Access

	test_db_path: STRING
			-- Path to test database.

feature -- Tests: Initialization

	test_oracle_creation
			-- Test oracle can be created.
		note
			testing: "covers/{SIMPLE_ORACLE}.make_memory_only"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			assert ("oracle is ready", oracle.is_ready)
			assert ("no error", not oracle.has_error)
			assert ("is memory only", oracle.is_memory_only)
		end

	test_oracle_is_ready
			-- Test is_ready query.
		note
			testing: "covers/{SIMPLE_ORACLE}.is_ready"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			assert ("is ready after creation", oracle.is_ready)
		end

feature -- Tests: Library Registry

	test_register_library
			-- Test library registration.
		note
			testing: "covers/{SIMPLE_ORACLE}.register_library"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			oracle.register_library ("simple_test", "D:\prod\simple_test")
			assert ("no error after registration", not oracle.has_error)
			assert ("library count is 1", oracle.library_count = 1)
		end

	test_library_count
			-- Test library count.
		note
			testing: "covers/{SIMPLE_ORACLE}.library_count"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			assert ("initially zero", oracle.library_count = 0)
			oracle.register_library ("lib1", "path1")
			assert ("count is 1", oracle.library_count = 1)
			oracle.register_library ("lib2", "path2")
			assert ("count is 2", oracle.library_count = 2)
		end

	test_all_libraries
			-- Test retrieving all libraries.
		note
			testing: "covers/{SIMPLE_ORACLE}.all_libraries"
		local
			oracle: SIMPLE_ORACLE
			libs: ARRAYED_LIST [TUPLE [name: STRING_32; path: STRING_32]]
		do
			create oracle.make_memory_only
			oracle.register_library ("alpha", "path_a")
			oracle.register_library ("beta", "path_b")
			libs := oracle.all_libraries
			assert ("has 2 libraries", libs.count = 2)
		end

feature -- Tests: Event Logging

	test_log_event
			-- Test event logging.
		note
			testing: "covers/{SIMPLE_ORACLE}.log_event"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			oracle.log_event ("compile", "simple_json", "success")
			assert ("no error", not oracle.has_error)
		end

	test_recent_events
			-- Test recent events retrieval.
		note
			testing: "covers/{SIMPLE_ORACLE}.recent_events"
		local
			oracle: SIMPLE_ORACLE
			events: ARRAYED_LIST [TUPLE [event_type: STRING_32; library: STRING_32; details: STRING_32; timestamp: STRING_32]]
		do
			create oracle.make_memory_only
			oracle.log_event ("test", "simple_sql", "passed")
			oracle.log_event ("compile", "simple_json", "failed")
			events := oracle.recent_events (4)
			assert ("has 2 events", events.count = 2)
		end

feature -- Tests: Knowledge Base

	test_add_knowledge
			-- Test adding knowledge.
		note
			testing: "covers/{SIMPLE_ORACLE}.add_knowledge"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			oracle.add_knowledge ("pattern", "inline C", "Use external C inline for Win32 calls")
			assert ("no error", not oracle.has_error)
			assert ("count is 1", oracle.knowledge_count = 1)
		end

	test_knowledge_count
			-- Test knowledge count.
		note
			testing: "covers/{SIMPLE_ORACLE}.knowledge_count"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			assert ("initially zero", oracle.knowledge_count = 0)
			oracle.add_knowledge ("api", "test1", "content1")
			oracle.add_knowledge ("pattern", "test2", "content2")
			assert ("count is 2", oracle.knowledge_count = 2)
		end

	test_fts_search
			-- Test FTS5 full-text search.
		note
			testing: "covers/{SIMPLE_ORACLE}.fts_search"
		local
			oracle: SIMPLE_ORACLE
			l_result: STRING_32
		do
			create oracle.make_memory_only
			oracle.add_knowledge ("pattern", "Inline C Pattern", "Use external C inline use header alias code for Win32 API calls")
			oracle.add_knowledge ("reference", "SCOOP Guide", "SCOOP provides safe concurrency with separate objects")
			l_result := oracle.query ("inline")
			assert ("found inline", l_result.has_substring ("Inline"))
		end

	test_clear_knowledge
			-- Test clearing knowledge.
		note
			testing: "covers/{SIMPLE_ORACLE}.clear_knowledge"
		local
			oracle: SIMPLE_ORACLE
		do
			create oracle.make_memory_only
			oracle.add_knowledge ("test", "test", "test content")
			assert ("has knowledge", oracle.knowledge_count = 1)
			oracle.clear_knowledge
			assert ("cleared", oracle.knowledge_count = 0)
		end

feature -- Tests: Expertise Injection

	test_inject_expertise
			-- Test expertise injection returns content.
		note
			testing: "covers/{SIMPLE_ORACLE}.inject_expertise"
		local
			oracle: SIMPLE_ORACLE
			expertise: STRING_32
		do
			create oracle.make_memory_only
			expertise := oracle.inject_expertise
			assert ("not empty", not expertise.is_empty)
			assert ("has eiffel content", expertise.has_substring ("EIFFEL"))
			assert ("has DBC", expertise.has_substring ("DBC"))
			assert ("has SCOOP", expertise.has_substring ("SCOOP"))
		end

	test_full_boot
			-- Test full boot sequence.
		note
			testing: "covers/{SIMPLE_ORACLE}.full_boot"
		local
			oracle: SIMPLE_ORACLE
			boot: STRING_32
		do
			create oracle.make_memory_only
			boot := oracle.full_boot
			assert ("not empty", not boot.is_empty)
			assert ("has expertise", boot.has_substring ("EXPERTISE"))
			assert ("has context", boot.has_substring ("CONTEXT"))
		end

	test_context_brief
			-- Test context brief generation.
		note
			testing: "covers/{SIMPLE_ORACLE}.context_brief"
		local
			oracle: SIMPLE_ORACLE
			brief: STRING_32
		do
			create oracle.make_memory_only
			oracle.register_library ("test_lib", "path")
			brief := oracle.context_brief
			assert ("not empty", not brief.is_empty)
			assert ("has libraries count", brief.has_substring ("Libraries:"))
		end

end
