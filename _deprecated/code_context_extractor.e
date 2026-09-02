note
	description: "[
		CODE_CONTEXT_EXTRACTOR - Extract code context around error location
		
		Reads source file and extracts ±radius lines around error line number
		for pattern extraction and failure analysis.
	]"
	author: "Claude"

class
	CODE_CONTEXT_EXTRACTOR

feature -- Extraction

	extract_context (a_file_path: READABLE_STRING_GENERAL; a_line: INTEGER; a_radius: INTEGER): STRING_32
		-- Extract code context from file: lines [a_line - a_radius .. a_line + a_radius].
		-- Returns formatted string with line numbers.
		require
			line_positive: a_line > 0
			radius_non_negative: a_radius >= 0
		local
			l_file: PLAIN_TEXT_FILE
			l_lines: ARRAYED_LIST [STRING_32]
			l_current_line: INTEGER
			l_start_line: INTEGER
			l_end_line: INTEGER
			l_result: STRING_32
		do
			create Result.make_empty
			create l_file.make (a_file_path.to_string_8)

			if l_file.exists and then l_file.is_readable then
				l_file.open_read

				-- Read all lines from file
				create l_lines.make (1000)
				from
					l_current_line := 1
				until
					l_file.end_of_file
				loop
					l_file.read_line
					l_lines.extend (l_file.last_string.to_string_32)
					l_current_line := l_current_line + 1
				end
				l_file.close

				-- Calculate range
				l_start_line := (a_line - a_radius).max (1)
				l_end_line := (a_line + a_radius).min (l_lines.count)

				-- Build context string with line numbers
				create l_result.make (a_radius * 2 * 80)
				from l_current_line := l_start_line
				until l_current_line > l_end_line
				loop
					l_result.append (l_current_line.out.right_justify (5) + ": ")
					if l_current_line <= l_lines.count then
						l_result.append (l_lines [l_current_line])
					end
					if l_current_line < l_end_line then
						l_result.append_character ('%N')
					end
					l_current_line := l_current_line + 1
				end

				Result := l_result
			end
		end

end
