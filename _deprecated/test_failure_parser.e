note
	description: "[
		TEST_FAILURE_PARSER - Parse EiffelTest failure output
		
		Extracts from test output:
		- Test name
		- Assertion/condition that failed
		- Expected vs actual values
		- Test class and location
	]"
	author: "Claude"

class
	TEST_FAILURE_PARSER

feature -- Parsing

	parse (a_output: READABLE_STRING_GENERAL): ARRAYED_LIST [TUPLE [
		test_name: STRING_32;
		assertion: STRING_32;
		expected: STRING_32;
		actual: STRING_32;
		location: STRING_32
	]]
		-- Parse test output, return list of failures found.
		local
			l_lines: ARRAYED_LIST [STRING_32]
			l_failures: ARRAYED_LIST [TUPLE [
				test_name: STRING_32;
				assertion: STRING_32;
				expected: STRING_32;
				actual: STRING_32;
				location: STRING_32
			]]
		do
			create l_failures.make (10)
			l_lines := split_lines (a_output.to_string_32)

			-- Find all "Test:" lines and process failures
			across l_lines.new_cursor as idx loop
				if l_lines.item (idx.index).starts_with ("Test:") then
					if is_failure (l_lines, idx.index) then
						-- Parse this test failure
						if attached extract_failure (l_lines, idx.index) as failure then
							l_failures.extend (failure)
						end
					end
				end
			end

			Result := l_failures
		end

feature {NONE} -- Extraction helpers

	is_failure (a_lines: ARRAYED_LIST [STRING_32]; a_start_index: INTEGER): BOOLEAN
		-- Check if test starting at a_start_index failed.
		local
			l_line: STRING_32
		do
			if a_start_index + 1 <= a_lines.count then
				l_line := a_lines.item (a_start_index + 1)
				Result := l_line.starts_with ("Status:") and l_line.contains_substring ("FAILED")
			end
		end

	extract_failure (a_lines: ARRAYED_LIST [STRING_32]; a_start_index: INTEGER): detachable TUPLE [
		test_name: STRING_32;
		assertion: STRING_32;
		expected: STRING_32;
		actual: STRING_32;
		location: STRING_32
	]
		-- Extract failure details from lines starting at a_start_index.
		local
			l_test_name: STRING_32
			l_assertion: STRING_32
			l_expected: STRING_32
			l_actual: STRING_32
			l_location: STRING_32
			l_line: STRING_32
			i: INTEGER
		do
			-- Extract test name from "Test: test_name [class]"
			l_test_name := extract_test_name (a_lines.item (a_start_index))

			-- Look for assertion, expected, actual in following lines
			from i := a_start_index + 2
			until i > a_lines.count or i > a_start_index + 20
			loop
				l_line := a_lines.item (i)

				if l_line.starts_with ("Assertion:") then
					l_assertion := l_line.substring (11, l_line.count).trim
				elseif l_line.starts_with ("Expected:") then
					l_expected := l_line.substring (10, l_line.count).trim
				elseif l_line.starts_with ("Actual:") then
					l_actual := l_line.substring (8, l_line.count).trim
				elseif l_line.starts_with ("Location:") then
					l_location := l_line.substring (10, l_line.count).trim
				elseif l_line.starts_with ("Test:") or l_line.is_empty then
					-- End of this failure record
					exit
				end

				i := i + 1
			end

			-- Return tuple if we found at least test name
			if not l_test_name.is_empty then
				Result := [l_test_name, l_assertion, l_expected, l_actual, l_location]
			end
		end

	extract_test_name (a_line: STRING_32): STRING_32
		-- Extract test name from "Test: test_name [ClassName]" format.
		local
			l_bracket_idx: INTEGER
		do
			if a_line.starts_with ("Test:") and a_line.count > 5 then
				Result := a_line.substring (6, a_line.count).trim
				-- Remove class name in brackets if present
				l_bracket_idx := Result.index_of ('[', 1)
				if l_bracket_idx > 0 then
					Result := Result.substring (1, l_bracket_idx - 1).trim.do_nothing
				end
			else
				create Result.make_empty
			end
		end

	split_lines (a_text: STRING_32): ARRAYED_LIST [STRING_32]
		-- Split text into lines.
		local
			l_lines: ARRAYED_LIST [STRING_32]
		do
			create l_lines.make (100)
			across a_text.split ('%N') as line loop
				l_lines.extend (line.item)
			end
			Result := l_lines
		end

end
