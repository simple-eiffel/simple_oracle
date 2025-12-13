note
	description: "Test application root for simple_oracle tests"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run all tests.
		local
			tests: LIB_TESTS
			passed, failed: INTEGER
		do
			create tests
			io.put_string ("=== SIMPLE_ORACLE TEST SUITE ===%N%N")

			-- Run each test
			run_test (agent tests.test_oracle_creation, "test_oracle_creation")
			run_test (agent tests.test_oracle_is_ready, "test_oracle_is_ready")
			run_test (agent tests.test_register_library, "test_register_library")
			run_test (agent tests.test_library_count, "test_library_count")
			run_test (agent tests.test_all_libraries, "test_all_libraries")
			run_test (agent tests.test_log_event, "test_log_event")
			run_test (agent tests.test_recent_events, "test_recent_events")
			run_test (agent tests.test_add_knowledge, "test_add_knowledge")
			run_test (agent tests.test_knowledge_count, "test_knowledge_count")
			run_test (agent tests.test_fts_search, "test_fts_search")
			run_test (agent tests.test_clear_knowledge, "test_clear_knowledge")
			run_test (agent tests.test_inject_expertise, "test_inject_expertise")
			run_test (agent tests.test_full_boot, "test_full_boot")
			run_test (agent tests.test_context_brief, "test_context_brief")

			-- Print summary
			io.put_string ("%N=== SUMMARY ===%N")
			io.put_string ("Passed: ")
			io.put_integer (test_passed)
			io.put_new_line
			io.put_string ("Failed: ")
			io.put_integer (test_failed)
			io.put_new_line

			if test_failed > 0 then
				io.put_string ("%NTEST SUITE FAILED%N")
			else
				io.put_string ("%NALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test execution

	test_passed: INTEGER
			-- Count of passed tests.

	test_failed: INTEGER
			-- Count of failed tests.

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test with error handling.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				io.put_string ("Running ")
				io.put_string (a_name)
				io.put_string ("... ")
				a_test.call (Void)
				io.put_string ("PASSED%N")
				test_passed := test_passed + 1
			end
		rescue
			io.put_string ("FAILED%N")
			if attached (create {EXCEPTION_MANAGER}).last_exception as ex then
				io.put_string ("  Error: ")
				if attached ex.description as desc then
					io.put_string (desc.to_string_8)
				end
				io.put_new_line
			end
			test_failed := test_failed + 1
			l_retried := True
			retry
		end

end
