note
	description: "[
		ORACLE_CLI - Command-line interface for simple_oracle.

		Commands:
			boot          - Full boot sequence (expertise + context injection)
			query         - Natural language query
			log           - Log an event
			compile       - Run ec.exe and log results
			compiles      - Show recent compile history
			test          - Run tests and log results
			tests         - Show recent test history
			git           - Scan and log git history
			commits       - Show recent commits
			dbc           - Generate DbC heatmap report
			scan-compiled - Scan EIFGENs metadata for accurate stats
			census        - Show ecosystem-wide statistics from compiled data
			status        - Ecosystem health check
			scan          - Rescan filesystem for libraries
			ingest        - Ingest reference docs into knowledge base
			learn         - Add a learning to knowledge base
			handoff       - Record/view session handoff
			check         - Show guidance (for "see oracle" trigger)
			help          - Show help

		Usage:
			oracle-cli boot
			oracle-cli query "what libraries use inline C?"
			oracle-cli log compile simple_json "success"
			oracle-cli test simple_json
			oracle-cli git simple_json 10
			oracle-cli check
			oracle-cli status
			oracle-cli scan
			oracle-cli scan-compiled [library]
			oracle-cli census
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	ORACLE_CLI

create
	make

feature {NONE} -- Initialization

	make
			-- Run the CLI.
		do
			create oracle.make
			parse_and_execute
		end

feature -- Access

	oracle: SIMPLE_ORACLE
			-- The oracle instance.

	args: ARGUMENTS_32
			-- Command line arguments.

feature {NONE} -- Command Parsing

	parse_and_execute
			-- Parse command line and execute appropriate command.
		local
			l_command: STRING_32
		do
			create args
			if args.argument_count < 1 then
				print_help
			else
				l_command := args.argument (1).as_lower
				if l_command.same_string ("boot") then
					execute_boot
				elseif l_command.same_string ("query") then
					execute_query
				elseif l_command.same_string ("log") then
					execute_log
				elseif l_command.same_string ("compile") then
					execute_compile
				elseif l_command.same_string ("compiles") then
					execute_compile_history
				elseif l_command.same_string ("status") then
					execute_status
				elseif l_command.same_string ("stats") then
					execute_stats
				elseif l_command.same_string ("scan") then
					execute_scan
				elseif l_command.same_string ("ingest") then
					execute_ingest
				elseif l_command.same_string ("learn") then
					execute_learn
				elseif l_command.same_string ("handoff") then
					execute_handoff
				elseif l_command.same_string ("check") then
					execute_check
				elseif l_command.same_string ("test") then
					execute_test
				elseif l_command.same_string ("tests") then
					execute_test_history
				elseif l_command.same_string ("git") then
					execute_git
				elseif l_command.same_string ("commits") then
					execute_commits
				elseif l_command.same_string ("dbc") then
					execute_dbc
				elseif l_command.same_string ("scan-compiled") then
					execute_scan_compiled
				elseif l_command.same_string ("census") then
					execute_census
			elseif l_command.same_string ("check-code") then
			execute_check_code
		elseif l_command.same_string ("patterns") then
			execute_patterns
		elseif l_command.same_string ("help") or l_command.same_string ("--help") or l_command.same_string ("-h") then
			print_help
		else
			io.put_string ("Unknown command: ")
			io.put_string (l_command.to_string_8)
			io.new_line
			print_help
		end
	end
	-- Close database connections before exit to prevent segfaults
	io.put_string ("%N[CLI] Closing oracle...%N")
	oracle.close
	io.put_string ("[CLI] Done.%N")
end

feature {NONE} -- Commands

	execute_boot
			-- Execute boot command - full expertise + context injection.
		do
			io.put_string (oracle.full_boot.to_string_8)
			io.new_line
		end

	execute_query
			-- Execute query command - natural language search.
		local
			l_question: STRING_32
			i: INTEGER
		do
			if args.argument_count < 2 then
				io.put_string ("Usage: oracle-cli query %"your question%"%N")
			else
				-- Concatenate all arguments after "query" as the question
				create l_question.make (100)
				from i := 2 until i > args.argument_count loop
					if i > 2 then
						l_question.append_character (' ')
					end
					l_question.append (args.argument (i))
					i := i + 1
				end
				io.put_string (oracle.query (l_question).to_string_8)
				io.new_line
			end
		end

	execute_log
			-- Execute log command - log an event.
			-- Usage: oracle-cli log <type> <library> <details>
		local
			l_type, l_library, l_details: STRING_32
			i: INTEGER
		do
			if args.argument_count < 3 then
				io.put_string ("Usage: oracle-cli log <type> [library] <details>%N")
				io.put_string ("Types: compile, test, git, file_change, error, info%N")
			else
				l_type := args.argument (2)
				if args.argument_count >= 4 then
					l_library := args.argument (3)
					-- Rest is details
					create l_details.make (100)
					from i := 4 until i > args.argument_count loop
						if i > 4 then
							l_details.append_character (' ')
						end
						l_details.append (args.argument (i))
						i := i + 1
					end
				else
					-- No library specified
					create l_library.make_empty
					l_details := args.argument (3)
				end
				oracle.log_event (l_type, l_library, l_details)
				if oracle.has_error then
					io.put_string ("Error: ")
					if attached oracle.last_error as err then
						io.put_string (err.to_string_8)
					end
					io.new_line
				else
					io.put_string ("Event logged.%N")
				end
			end
		end

	execute_compile
			-- Execute compile command - run ec.exe and log results.
			-- Usage: oracle-cli compile <library> [target]
		local
			l_library, l_target: STRING_32
			l_process: SIMPLE_PROCESS
			l_command: STRING_32
			l_start: INTEGER
			l_duration: REAL_64
			l_success: BOOLEAN
		do
			if args.argument_count < 2 then
				io.put_string ("Usage: oracle-cli compile <library> [target]%N")
				io.put_string ("Example: oracle-cli compile simple_json simple_json_tests%N")
			else
				l_library := args.argument (2)
				if args.argument_count >= 3 then
					l_target := args.argument (3)
				else
					l_target := l_library + "_tests"
				end

				io.put_string ("Compiling: ")
				io.put_string (l_library.to_string_8)
				io.put_string (" (target: ")
				io.put_string (l_target.to_string_8)
				io.put_string (")%N")

				-- Build command
				create l_command.make (300)
				l_command.append ("%"C:\Program Files\Eiffel Software\EiffelStudio 25.02 Standard\studio\spec\win64\bin\ec.exe%" -batch -config %"D:\prod\")
				l_command.append (l_library)
				l_command.append ("\")
				l_command.append (l_library)
				l_command.append (".ecf%" -target ")
				l_command.append (l_target)
				l_command.append (" -c_compile")

				-- Execute
				create l_process.make
				l_start := (create {SIMPLE_DATE_TIME}.make_now).to_timestamp.to_integer
				l_process.run_in_directory (l_command, "D:\prod\" + l_library)
				l_duration := ((create {SIMPLE_DATE_TIME}.make_now).to_timestamp.to_integer - l_start).to_double

				-- Check success
				l_success := l_process.succeeded and then l_process.exit_code = 0
				if attached l_process.stdout as l_out then
					if not l_out.has_substring ("C compilation completed") and not l_out.has_substring ("System Recompiled") then
						l_success := False
					end
				end

				-- Log to oracle
				oracle.log_compile (l_library, l_target, l_success, l_duration)

				-- Output result
				io.new_line
				if l_success then
					io.put_string ("=== COMPILE SUCCESS ===%N")
				else
					io.put_string ("=== COMPILE FAILED ===%N")
					if attached l_process.stdout as l_out then
						io.put_string (last_n_lines (l_out.to_string_8, 30))
					end
				end
				io.put_string ("Duration: ")
				io.put_integer (l_duration.truncated_to_integer)
				io.put_string ("s%N")
			end
		end

	execute_compile_history
			-- Show recent compile history.
		do
			io.put_string ("=== COMPILE HISTORY ===%N%N")
			across oracle.recent_compiles (20) as ic_c loop
				io.put_string ("[")
				io.put_string (ic_c.timestamp.to_string_8)
				io.put_string ("] ")
				io.put_string (ic_c.library.to_string_8)
				io.put_string ("/")
				io.put_string (ic_c.target.to_string_8)
				io.put_string (": ")
				if ic_c.success then
					io.put_string ("SUCCESS")
				else
					io.put_string ("FAILED")
				end
				io.put_string (" (")
				io.put_integer (ic_c.duration.truncated_to_integer)
				io.put_string ("s)%N")
			end
		end

	execute_status
			-- Execute status command - ecosystem health check.
		do
			io.put_string ("=== ORACLE STATUS ===%N%N")
			io.put_string ("Database: ")
			if oracle.is_ready then
				io.put_string ("READY%N")
			else
				io.put_string ("NOT READY%N")
			end
			io.put_string ("Libraries: ")
			io.put_integer (oracle.library_count)
			io.new_line

			-- Recent events summary
			io.put_string ("%NRecent Events (4h):%N")
			across oracle.recent_events (4) as ev loop
				io.put_string ("  [")
				io.put_string (ev.event_type.to_string_8)
				io.put_string ("] ")
				if not ev.library.is_empty then
					io.put_string (ev.library.to_string_8)
					io.put_string (": ")
				end
				io.put_string (ev.details.substring (1, ev.details.count.min (50)).to_string_8)
				io.new_line
			end
		end

	execute_stats
			-- Execute stats command - ecosystem metrics for management/bean-counters.
			-- Shows work metrics over various time periods.
		local
			l_period: STRING_32
		do
			if args.argument_count >= 2 then
				l_period := args.argument (2).as_lower
			else
				l_period := "all"
			end
			io.put_string (oracle.ecosystem_stats (l_period).to_string_8)
		end

	execute_scan
			-- Execute scan command - full ecosystem scan with class/feature extraction.
		local
			l_scanner: ORACLE_ECOSYSTEM_SCANNER
			l_lib_count, l_class_count, l_feat_count: INTEGER
			l_lib_names: STRING_32
		do
			io.put_string ("Scanning ecosystem at D:\prod\simple_*...%N")
			io.put_string ("Extracting: libraries, classes, features, DBC contracts%N%N")

			create l_scanner.make (oracle)
			l_scanner.scan_ecosystem ("D:\prod")

			-- Capture values before scanner cleanup
			l_lib_count := l_scanner.library_count
			l_class_count := l_scanner.class_count
			l_feat_count := l_scanner.feature_count

			-- Build library names string
			create l_lib_names.make (2000)
			across l_scanner.libraries_found as lib loop
				l_lib_names.append ("  ")
				l_lib_names.append (lib.name)
				l_lib_names.append ("%N")
			end

			-- Clear scanner lists to free memory before output
			l_scanner.libraries_found.wipe_out
			l_scanner.classes_found.wipe_out
			l_scanner.features_found.wipe_out

			io.put_string ("=== SCAN COMPLETE ===%N")
			io.put_string ("Libraries: ")
			io.put_integer (l_lib_count)
			io.new_line
			io.put_string ("Classes:   ")
			io.put_integer (l_class_count)
			io.new_line
			io.put_string ("Features:  ")
			io.put_integer (l_feat_count)
			io.new_line

			-- Show libraries
			if l_lib_count > 0 then
				io.put_string ("%NLibraries found:%N")
				io.put_string (l_lib_names.to_string_8)
			end
		end

	execute_ingest
			-- Execute ingest command - ingest reference docs into knowledge base.
		local
			l_path: STRING_32
		do
			if args.argument_count >= 2 then
				l_path := args.argument (2)
			else
				l_path := "D:\prod\reference_docs"
			end
			io.put_string ("Clearing existing knowledge base...%N")
			oracle.clear_knowledge
			io.put_string ("Ingesting from: ")
			io.put_string (l_path.to_string_8)
			io.new_line
			oracle.ingest_directory (l_path)
			io.put_string ("%NIngestion complete. Knowledge entries: ")
			io.put_integer (oracle.knowledge_count)
			io.new_line
		end

	execute_learn
			-- Execute learn command - add a learning to the knowledge base.
			-- Usage: oracle-cli learn <category> <title> <content>
		local
			l_category, l_title, l_content: STRING_32
			i: INTEGER
		do
			if args.argument_count < 4 then
				io.put_string ("Usage: oracle-cli learn <category> <title> <content>%N")
				io.put_string ("Categories: pattern, rule, gotcha, decision, insight%N")
				io.put_string ("Example: oracle-cli learn rule %"Use simple_process%" %"Always use simple_process, never ISE process library%"%N")
			else
				l_category := args.argument (2)
				l_title := args.argument (3)
				-- Concatenate remaining args as content
				create l_content.make (200)
				from i := 4 until i > args.argument_count loop
					if i > 4 then
						l_content.append_character (' ')
					end
					l_content.append (args.argument (i))
					i := i + 1
				end
				oracle.add_knowledge (l_category, l_title, l_content)
				if oracle.has_error then
					io.put_string ("Error: ")
					if attached oracle.last_error as err then
						io.put_string (err.to_string_8)
					end
					io.new_line
				else
					io.put_string ("Learned: [")
					io.put_string (l_category.to_string_8)
					io.put_string ("] ")
					io.put_string (l_title.to_string_8)
					io.new_line
					io.put_string ("Knowledge count: ")
					io.put_integer (oracle.knowledge_count)
					io.new_line
				end
			end
		end

	execute_check
			-- Execute check command - show all guidance, warnings, and rules.
			-- Called when Larry says "see oracle" or "consult oracle".
			-- This forces Claude to pay attention to oracle knowledge.
		do
			io.put_string (oracle.check_guidance.to_string_8)
			io.new_line
		end

	execute_test
			-- Execute test command - run tests and log results.
			-- Usage: oracle-cli test <library> [target]
		local
			l_library, l_target: STRING_32
			l_process: SIMPLE_PROCESS
			l_command: STRING_32
			l_start: INTEGER
			l_duration: REAL_64
			l_total, l_passed, l_failed: INTEGER
			l_output: STRING_8
		do
			if args.argument_count < 2 then
				io.put_string ("Usage: oracle-cli test <library> [target]%N")
				io.put_string ("Example: oracle-cli test simple_json simple_json_tests%N")
			else
				l_library := args.argument (2)
				if args.argument_count >= 3 then
					l_target := args.argument (3)
				else
					l_target := l_library + "_tests"
				end

				io.put_string ("Running tests: ")
				io.put_string (l_library.to_string_8)
				io.put_string (" (target: ")
				io.put_string (l_target.to_string_8)
				io.put_string (")%N")

				-- Build path to test executable
				create l_command.make (300)
				l_command.append ("D:\prod\")
				l_command.append (l_library)
				l_command.append ("\EIFGENs\")
				l_command.append (l_target)
				l_command.append ("\W_code\")
				l_command.append (l_library)
				l_command.append (".exe")

				-- Execute
				create l_process.make
				l_start := (create {SIMPLE_DATE_TIME}.make_now).to_timestamp.to_integer
				l_process.run (l_command)
				l_duration := ((create {SIMPLE_DATE_TIME}.make_now).to_timestamp.to_integer - l_start).to_double

				-- Parse output for test results
				if attached l_process.stdout as l_out then
					l_output := l_out.to_string_8
					if attached parse_test_output (l_output) as l_results then
						l_total := l_results.total
						l_passed := l_results.passed
						l_failed := l_results.failed
					end
				else
					create l_output.make_empty
					l_total := 0
					l_passed := 0
					l_failed := 0
				end

				-- Log to oracle
				oracle.log_test_run (l_library, l_target, l_total, l_passed, l_failed, l_duration, l_output)

				-- Output result
				io.new_line
				if l_failed = 0 and l_passed > 0 then
					io.put_string ("=== TESTS PASSED ===%N")
				elseif l_failed > 0 then
					io.put_string ("=== TESTS FAILED ===%N")
				else
					io.put_string ("=== TEST RUN COMPLETE ===%N")
				end
				io.put_string ("Total: ")
				io.put_integer (l_total)
				io.put_string ("  Passed: ")
				io.put_integer (l_passed)
				io.put_string ("  Failed: ")
				io.put_integer (l_failed)
				io.put_string ("%NDuration: ")
				io.put_integer (l_duration.truncated_to_integer)
				io.put_string ("s%N")

				-- Show last 20 lines if failures
				if l_failed > 0 then
					io.put_string ("%NOutput (last 20 lines):%N")
					io.put_string (last_n_lines (l_output, 20))
				end
			end
		end

	execute_test_history
			-- Show recent test run history.
		do
			io.put_string ("=== TEST HISTORY ===%N%N")
			across oracle.recent_test_runs (20) as ic_t loop
				io.put_string ("[")
				io.put_string (ic_t.timestamp.to_string_8)
				io.put_string ("] ")
				io.put_string (ic_t.library.to_string_8)
				io.put_string (": ")
				io.put_integer (ic_t.passed)
				io.put_string ("/")
				io.put_integer (ic_t.total)
				io.put_string (" passed")
				if ic_t.failed > 0 then
					io.put_string (" (")
					io.put_integer (ic_t.failed)
					io.put_string (" FAILED)")
				end
				io.put_string (" (")
				io.put_integer (ic_t.duration.truncated_to_integer)
				io.put_string ("s)%N")
			end

			-- Show failing libraries
			if not oracle.failing_libraries.is_empty then
				io.put_string ("%N=== LIBRARIES WITH FAILURES ===%N")
				across oracle.failing_libraries as ic_f loop
					io.put_string ("  ")
					io.put_string (ic_f.library.to_string_8)
					io.put_string (": ")
					io.put_integer (ic_f.last_failed)
					io.put_string (" failures (")
					io.put_string (ic_f.last_run.to_string_8)
					io.put_string (")%N")
				end
			end
		end

	execute_git
			-- Execute git command - scan and log git history for a library.
			-- Usage: oracle-cli git <library> [count]
		local
			l_library: STRING_32
			l_count: INTEGER
			l_process: SIMPLE_PROCESS
			l_command, l_lib_path: STRING_32
			l_output: STRING_8
			l_lines: LIST [STRING_8]
			l_parts: LIST [STRING_8]
			l_hash, l_author, l_message: STRING_8
			l_files, l_ins, l_del: INTEGER
			l_logged: INTEGER
		do
			if args.argument_count < 2 then
				io.put_string ("Usage: oracle-cli git <library> [count]%N")
				io.put_string ("Example: oracle-cli git simple_json 10%N")
				io.put_string ("Scans git log and records commits to oracle.%N")
			else
				l_library := args.argument (2)
				if args.argument_count >= 3 and then args.argument (3).is_integer then
					l_count := args.argument (3).to_integer
				else
					l_count := 10
				end

				create l_lib_path.make (100)
				l_lib_path.append ("D:\prod\")
				l_lib_path.append (l_library)

				io.put_string ("Scanning git history for: ")
				io.put_string (l_library.to_string_8)
				io.put_string (" (last ")
				io.put_integer (l_count)
				io.put_string (" commits)%N")

				-- Get git log with stats
				-- Format: hash|author|message|files|insertions|deletions
				create l_command.make (300)
				l_command.append ("git -C %"")
				l_command.append (l_lib_path)
				l_command.append ("%" log --pretty=format:%%H|%%an|%%s -n ")
				l_command.append (l_count.out)
				l_command.append (" --shortstat")

				create l_process.make
				l_process.run (l_command)

				-- Initialize to empty strings (not detachable)
				create l_hash.make_empty
				create l_author.make_empty
				create l_message.make_empty

				if attached l_process.stdout as l_git_out then
					l_output := l_git_out.to_string_8
					l_lines := l_output.split ('%N')
					from l_lines.start until l_lines.after loop
						if not l_lines.item.is_empty then
							if l_lines.item.has ('|') then
								-- This is a commit line: hash|author|message
								l_parts := l_lines.item.split ('|')
								if l_parts.count >= 3 then
									l_hash := l_parts.i_th (1)
									l_author := l_parts.i_th (2)
									l_message := l_parts.i_th (3)
									-- Reset stats for next commit
									l_files := 0
									l_ins := 0
									l_del := 0
								end
							elseif l_lines.item.has_substring ("file") or l_lines.item.has_substring ("insertion") or l_lines.item.has_substring ("deletion") then
								-- This is a stat line, parse and log the commit
								if attached parse_git_stats (l_lines.item) as l_stats then
									l_files := l_stats.files
									l_ins := l_stats.insertions
									l_del := l_stats.deletions
								end
								if not l_hash.is_empty then
									oracle.log_git_commit (l_library, l_hash, l_author, l_message, l_files, l_ins, l_del)
									l_logged := l_logged + 1
									l_hash.wipe_out
								end
							end
						end
						l_lines.forth
					end
					-- Log last commit if no stat line followed
					if not l_hash.is_empty then
						oracle.log_git_commit (l_library, l_hash, l_author, l_message, 0, 0, 0)
						l_logged := l_logged + 1
					end
				end

				io.put_string ("Logged ")
				io.put_integer (l_logged)
				io.put_string (" commits.%N")
			end
		end

	execute_commits
			-- Show recent git commits across all libraries.
		local
			l_stats: TUPLE [total_commits: INTEGER; libraries_with_commits: INTEGER; total_insertions: INTEGER; total_deletions: INTEGER]
		do
			io.put_string ("=== RECENT COMMITS ===%N%N")
			across oracle.recent_commits (20) as ic_c loop
				io.put_string ("[")
				io.put_string (ic_c.timestamp.to_string_8)
				io.put_string ("] ")
				io.put_string (ic_c.library.to_string_8)
				io.put_string (" ")
				io.put_string (ic_c.hash.substring (1, (7).min (ic_c.hash.count)).to_string_8)
				io.put_string (": ")
				io.put_string (ic_c.message.substring (1, (50).min (ic_c.message.count)).to_string_8)
				if ic_c.message.count > 50 then
					io.put_string ("...")
				end
				io.new_line
			end

			-- Show stats
			l_stats := oracle.git_stats
			io.put_string ("%N=== GIT STATS ===%N")
			io.put_string ("Total commits logged: ")
			io.put_integer (l_stats.total_commits)
			io.put_string ("%NLibraries with commits: ")
			io.put_integer (l_stats.libraries_with_commits)
			io.put_string ("%NTotal insertions: +")
			io.put_integer (l_stats.total_insertions)
			io.put_string ("%NTotal deletions: -")
			io.put_integer (l_stats.total_deletions)
			io.new_line
		end

	execute_dbc
			-- Execute dbc command - generate DbC heatmap report.
			-- Usage: oracle-cli dbc [output_file.html]
		local
			l_analyzer: DBC_HEATMAP_ANALYZER
			l_ucf: SIMPLE_UCF
			l_output: STRING
		do
			io.put_string ("=== DbC HEATMAP ANALYZER ===%N%N")
			io.put_string ("Discovering libraries from environment...%N")

			create l_ucf.make
			l_ucf.discover_from_environment

			if l_ucf.is_valid then
				io.put_string ("Found " + l_ucf.libraries.count.out + " libraries%N%N")
				io.put_string ("Analyzing DbC coverage...%N")

				create l_analyzer.make
				l_analyzer.analyze_from_ucf (l_ucf)

				-- Output summary
				io.put_string ("%N=== SUMMARY ===%N")
				io.put_string ("Overall Score: " + l_analyzer.overall_score.out + "%%%N")
				io.put_string ("Total Classes: " + l_analyzer.total_classes.out + "%N")
				io.put_string ("Total Features: " + l_analyzer.total_features.out + "%N")
				io.put_string ("With Require: " + l_analyzer.total_with_require.out + "%N")
				io.put_string ("With Ensure: " + l_analyzer.total_with_ensure.out + "%N")
				io.put_string ("With Invariant: " + l_analyzer.total_with_invariant.out + "%N")

				-- Generate HTML report
				if args.argument_count >= 2 then
					l_output := args.argument (2).to_string_8
				else
					l_output := "dbc_heatmap.html"
				end

				io.put_string ("%NGenerating HTML report: " + l_output + "%N")
				l_analyzer.generate_html_report (l_output)
				io.put_string ("Done! Open " + l_output + " in a browser to view.%N")
			else
				io.put_string ("ERROR: No SIMPLE_* environment variables found%N")
			end
		end

	execute_scan_compiled
			-- Execute scan-compiled command - scan EIFGENs metadata for accurate stats.
			-- Usage: oracle-cli scan-compiled [library]
		local
			l_library: STRING_32
			l_scanner: ORACLE_ECOSYSTEM_SCANNER
			l_ucf: SIMPLE_UCF
		do
			io.put_string ("=== SCAN COMPILED (EIFGENs Metadata) ===%N%N")

			-- Get library list from UCF
			create l_ucf.make
			l_ucf.discover_from_environment

			if not l_ucf.is_valid then
				io.put_string ("ERROR: No SIMPLE_* environment variables found%N")
			else
				create l_scanner.make (oracle)

				if args.argument_count >= 2 then
					-- Scan specific library
					l_library := args.argument (2)
					io.put_string ("Scanning ")
					io.put_string (l_library.to_string_8)
					io.put_string ("...%N")
					scan_single_library (l_scanner, l_library, l_ucf)
				else
					-- Scan all libraries
					io.put_string ("Scanning all ")
					io.put_integer (l_ucf.libraries.count)
					io.put_string (" libraries...%N%N")
					across l_ucf.libraries as lib loop
						io.put_string ("  ")
						io.put_string (lib.name.to_string_8)
						io.put_string ("... ")
						scan_single_library (l_scanner, lib.name, l_ucf)
					end
				end

				io.put_string ("%N=== SCAN COMPLETE ===%N")
			end
		end

	scan_single_library (a_scanner: ORACLE_ECOSYSTEM_SCANNER; a_library: STRING_32; a_ucf: SIMPLE_UCF)
			-- Scan a single library's source code for statistics.
		local
			l_lib: detachable UCF_LIBRARY
			l_src_path: STRING_32
			l_parser: SOURCE_STATS_PARSER
			l_stats: TUPLE [class_count, feature_count, attribute_count, lines_of_code,
				precondition_count, postcondition_count, invariant_count: INTEGER;
				src_path: STRING_32]
			l_src_file: SIMPLE_FILE
		do
			l_lib := a_ucf.library_by_name (a_library)
			if attached l_lib then
				-- Find src directory
				l_src_path := l_lib.resolved_path + "/src"
				create l_src_file.make (l_src_path)

				if l_src_file.is_directory then
					-- Parse source files
					create l_parser.make
					l_parser.parse_source (l_src_path)

					if l_parser.is_parsed then
						-- Store stats
						l_stats := [l_parser.class_count, l_parser.feature_count, l_parser.attribute_count,
							l_parser.lines_of_code, l_parser.precondition_count, l_parser.postcondition_count,
							l_parser.invariant_count, l_src_path]
						oracle.store_compiled_stats (a_library, "source", l_stats)

						io.put_string (l_parser.class_count.out)
						io.put_string (" classes, ")
						io.put_string (l_parser.feature_count.out)
						io.put_string (" features, ")
						io.put_string (l_parser.lines_of_code.out)
						io.put_string (" LOC%N")
					else
						io.put_string ("PARSE ERROR")
						across l_parser.errors as err loop
							io.put_string (" - ")
							io.put_string (err.to_string_8)
						end
						io.new_line
					end
				else
					io.put_string ("no src/ directory%N")
				end
			else
				io.put_string ("library not found%N")
			end
		end

	find_e1_directory (a_eifgens_path: STRING_32): STRING_32
			-- Find first E1 directory in EIFGENs subdirectories.
		local
			l_file: SIMPLE_FILE
			l_dirs: ARRAYED_LIST [STRING_32]
			l_candidate: STRING_32
			l_candidate_file: SIMPLE_FILE
		do
			create Result.make_empty
			create l_file.make (a_eifgens_path)

			-- List directories in EIFGENs
			l_dirs := l_file.directories
			across l_dirs as dir loop
				l_candidate := a_eifgens_path + "/" + dir + "/W_code/E1"
				create l_candidate_file.make (l_candidate)
				if l_candidate_file.is_directory then
					Result := l_candidate
				end
			end
		end

	extract_target_from_path (a_e1_path: STRING_32): STRING_32
			-- Extract target name from E1 path.
			-- Path like: /path/EIFGENs/simple_json_tests/W_code/E1
		local
			l_parts: LIST [STRING_32]
		do
			l_parts := a_e1_path.split ('/')
			if l_parts.count >= 3 then
				Result := l_parts [l_parts.count - 2] -- Target is 3rd from end
			else
				create Result.make_from_string ("unknown")
			end
		end

	execute_census
			-- Execute census command - show ecosystem-wide statistics from compiled data.
		do
			io.put_string (oracle.ecosystem_census.to_string_8)
		end

	execute_handoff
			-- Execute handoff command - record session handoff for context continuity.
			-- Usage: oracle-cli handoff <current_task> [work_in_progress] [next_steps] [blockers]
			-- Or: oracle-cli handoff (with no args shows last handoff)
		local
			l_task, l_wip, l_next, l_blockers: detachable STRING_32
		do
			if args.argument_count < 2 then
				-- No args: show last handoff
				io.put_string (oracle.handoff_brief.to_string_8)
				io.new_line
			else
				-- Record new handoff
				l_task := args.argument (2)
				if args.argument_count >= 3 then
					l_wip := args.argument (3)
				end
				if args.argument_count >= 4 then
					l_next := args.argument (4)
				end
				if args.argument_count >= 5 then
					l_blockers := args.argument (5)
				end
				oracle.record_handoff (l_task, l_wip, l_next, l_blockers)
				if oracle.has_error then
					io.put_string ("Error: ")
					if attached oracle.last_error as err then
						io.put_string (err.to_string_8)
					end
					io.new_line
				else
					io.put_string ("Session handoff recorded.%N")
					io.put_string ("  Task: ")
					if attached l_task as t then io.put_string (t.to_string_8) end
					io.new_line
					if attached l_wip as w and then not w.is_empty then
						io.put_string ("  WIP: ")
						io.put_string (w.to_string_8)
						io.new_line
					end
					if attached l_next as n and then not n.is_empty then
						io.put_string ("  Next: ")
						io.put_string (n.to_string_8)
						io.new_line
					end
					if attached l_blockers as b and then not b.is_empty then
						io.put_string ("  Blockers: ")
						io.put_string (b.to_string_8)
						io.new_line
					end
				end
			end
		end

	execute_check_code
		-- **ORACLE GATE** - Check code against known failure patterns.
		local
			l_code: STRING_32
			l_library: STRING_32
			l_is_stdin: BOOLEAN
			l_matches: ARRAYED_LIST [TUPLE [pattern_id: INTEGER; pattern_literal: STRING_32; description: STRING_32; severity: STRING_32]]
			l_match_count: INTEGER
			i: INTEGER
		do
			-- Parse arguments: check-code [<file>] --stdin --library LIBRARY
			l_library := "simple_onnx"
			l_is_stdin := False

			-- Find --library and --stdin arguments
			from i := 1 until i > args.argument_count loop
				if args.argument (i).same_string ("--stdin") then
					l_is_stdin := True
				end
				if args.argument (i).same_string ("--library") and then i < args.argument_count then
					l_library := args.argument (i + 1).as_string_32
				end
				i := i + 1
			end

			-- Read code source
			if l_is_stdin then
				-- Read from standard input line by line
				create l_code.make (10000)
				from
				until
					io.input.end_of_file
				loop
					io.input.read_line
					l_code.append (io.input.last_string.as_string_32)
					if not io.input.end_of_file then
						l_code.append_character ('%N')
					end
				end
			else
				-- No input provided
				create l_code.make (100)
			end

			-- Check code against patterns
			if oracle /= Void and then l_code.count > 0 then
				l_matches := oracle.check_code_pattern (l_code, l_library)
				l_match_count := l_matches.count

				if l_match_count > 0 then
					-- Code flagged - matches known failure patterns
					io.put_string ("[oracle-gate] Code flagged - ")
					io.put_integer (l_match_count)
					io.put_string (" pattern match")
					if l_match_count > 1 then
						io.put_string ("es")
					end
					io.put_string (" found%N%N")

					-- Show pattern summary
					io.put_string ("Known failure patterns detected:%N")
					io.put_integer (l_match_count)
					io.put_string (" pattern(s) match your code%N%N")
					io.put_string ("Suggestion: Review similar failures in oracle database or regenerate code%N")
				else
					-- Code passed - no known failure patterns detected
					io.put_string ("[oracle-gate] Code check passed - no known failure patterns detected%N")
				end
			else
				io.put_string ("[oracle-gate] Code check ready%N")
			end
		end

	execute_patterns
		-- List all failure patterns for a library.
		do
			if args.argument_count >= 2 then
				io.put_string ("Patterns for: ")
				io.put_string (args.argument (2).to_string_8)
				io.put_string ("%N")
			else
				io.put_string ("Usage: oracle-cli patterns [LIBRARY]%N")
			end
		end


feature {NONE} -- Helpers

	last_n_lines (a_text: STRING_8; n: INTEGER): STRING_8
			-- Return last n lines of a_text.
		local
			l_lines: LIST [STRING_8]
			i, start_index: INTEGER
		do
			l_lines := a_text.split ('%N')
			create Result.make (2000)
			start_index := (l_lines.count - n + 1).max (1)
			from i := start_index until i > l_lines.count loop
				Result.append (l_lines.i_th (i))
				Result.append_character ('%N')
				i := i + 1
			end
		end

	parse_test_output (a_output: STRING_8): TUPLE [total: INTEGER; passed: INTEGER; failed: INTEGER]
			-- Parse test runner output to extract test counts.
			-- EiffelStudio test output format: "Executed N of N tests. N passed, N failed."
		local
			l_lines: LIST [STRING_8]
			l_line: STRING_8
			l_passed_val, l_failed_val: INTEGER
			l_pos, l_end: INTEGER
			l_num: STRING_8
		do
			l_lines := a_output.split ('%N')
			across l_lines as line loop
				l_line := line
				-- Look for patterns like "X passed" or "X failed"
				if l_line.has_substring (" passed") then
					l_pos := l_line.substring_index (" passed", 1)
					if l_pos > 1 then
						-- Find the number before " passed"
						l_end := l_pos - 1
						from l_pos := l_end until l_pos < 1 or else not l_line.item (l_pos).is_digit loop
							l_pos := l_pos - 1
						end
						if l_pos < l_end then
							l_num := l_line.substring (l_pos + 1, l_end)
							if l_num.is_integer then
								l_passed_val := l_num.to_integer
							end
						end
					end
				end
				if l_line.has_substring (" failed") then
					l_pos := l_line.substring_index (" failed", 1)
					if l_pos > 1 then
						l_end := l_pos - 1
						from l_pos := l_end until l_pos < 1 or else not l_line.item (l_pos).is_digit loop
							l_pos := l_pos - 1
						end
						if l_pos < l_end then
							l_num := l_line.substring (l_pos + 1, l_end)
							if l_num.is_integer then
								l_failed_val := l_num.to_integer
							end
						end
					end
				end
			end
			Result := [l_passed_val + l_failed_val, l_passed_val, l_failed_val]
		end

	parse_git_stats (a_line: STRING_8): TUPLE [files: INTEGER; insertions: INTEGER; deletions: INTEGER]
			-- Parse git --shortstat line to extract file/insertion/deletion counts.
			-- Format: " 3 files changed, 10 insertions(+), 5 deletions(-)"
		local
			l_parts: LIST [STRING_8]
			l_part: STRING_8
			l_files_val, l_ins_val, l_del_val: INTEGER
			l_num: STRING_8
			i: INTEGER
		do
			l_parts := a_line.split (',')
			across l_parts as part loop
				l_part := part
				l_part.left_adjust
				l_part.right_adjust
				if l_part.has_substring ("file") then
					-- Extract number before "file"
					create l_num.make (10)
					from i := 1 until i > l_part.count or else not l_part.item (i).is_digit loop
						l_num.append_character (l_part.item (i))
						i := i + 1
					end
					if l_num.is_integer then
						l_files_val := l_num.to_integer
					end
				elseif l_part.has_substring ("insertion") then
					create l_num.make (10)
					from i := 1 until i > l_part.count or else not l_part.item (i).is_digit loop
						l_num.append_character (l_part.item (i))
						i := i + 1
					end
					if l_num.is_integer then
						l_ins_val := l_num.to_integer
					end
				elseif l_part.has_substring ("deletion") then
					create l_num.make (10)
					from i := 1 until i > l_part.count or else not l_part.item (i).is_digit loop
						l_num.append_character (l_part.item (i))
						i := i + 1
					end
					if l_num.is_integer then
						l_del_val := l_num.to_integer
					end
				end
			end
			Result := [l_files_val, l_ins_val, l_del_val]
		end

feature {NONE} -- Helpers

	read_file (a_path: STRING_32): detachable STRING_32
		-- Read entire file contents into a string.
		-- Phase 4: Placeholder - actual file I/O implemented via claude_tools
		do
			create Result.make (100)
			Result.append ("File read not yet implemented%N")
		end


feature {NONE} -- Help

	print_help
			-- Print usage help.
		do
			io.put_string ("[
simple_oracle - Claude's External Memory and Development Intelligence Platform

USAGE:
  oracle-cli <command> [arguments]

COMMANDS:
  boot              Full boot sequence (expertise + context injection)
  query <question>  Natural language query
  log <type> [lib] <details>
                    Log an event
  compile <lib>     Run ec.exe and log results
  compiles          Show recent compile history
  test <lib>        Run tests and log results
  tests             Show recent test history
  git <lib> [count] Scan git log and record commits
  commits           Show recent commits
  status            Show ecosystem health
  stats [period]    Show ecosystem metrics
  scan              Rescan filesystem for libraries
  ingest [path]     Ingest reference docs
  learn <cat> <title> <content>
                    Add learning to knowledge base
  handoff [args]    Record/view session handoff
  check             Show guidance and rules
  check-code        Check code against failure patterns (ORACLE GATE)
  patterns [lib]    List failure patterns
  help              Show this help message

For complete documentation, visit: https://github.com/simple-eiffel

]")
		end

end
