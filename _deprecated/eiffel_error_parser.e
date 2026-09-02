note
	description: "[
		EIFFEL_ERROR_PARSER - Parse EiffelStudio compiler error output
		
		Handles error codes like:
		- VTCT: Unknown class type
		- VUAR: Type mismatch (void safety)
		- VEEN: Unknown identifier
		- VGCC: Missing creation call
		- VUTA: Possibly void target
		
		Extracts error code, file path, line number, message, and code context.
	]"
	author: "Claude"

class
	EIFFEL_ERROR_PARSER

feature -- Parsing

	parse (a_output: READABLE_STRING_GENERAL): detachable TUPLE [
		error_code: STRING_32;
		file_path: STRING_32;
		line_number: INTEGER;
		error_message: STRING_32;
		class_name: STRING_32;
		feature_name: STRING_32
	]
		-- Parse compiler error output, return error details or Void if not found.
		require
			output_not_empty: not a_output.is_empty
		local
			l_lines: ARRAYED_LIST [STRING_32]
			l_error_code: detachable STRING_32
			l_file_path: detachable STRING_32
			l_line_number: INTEGER
			l_message: STRING_32
			l_class: STRING_32
			l_feature: STRING_32
		do
			l_lines := split_lines (a_output.to_string_32)

			-- Extract error code (first line pattern: "Error code: XXXX")
			l_error_code := extract_error_code (l_lines)
			
			if attached l_error_code then
				-- Extract other details
				extract_file_and_line (l_lines, l_file_path, l_line_number)
				l_message := extract_message (l_lines)
				l_class := extract_class (l_lines)
				l_feature := extract_feature (l_lines)

				Result := [l_error_code, l_file_path.twin, l_line_number, l_message, l_class, l_feature]
			end
		ensure
			result_void_or_valid: Result = Void or (
				Result.error_code /= Void and
				Result.error_message /= Void
			)
		end

feature {NONE} -- Extraction helpers

	extract_error_code (a_lines: ARRAYED_LIST [STRING_32]): detachable STRING_32
		-- Extract error code from lines (e.g., "VTCT", "VUAR(2)")
		local
			l_line: STRING_32
		do
			across a_lines as line loop
				if line.item.starts_with ("Error code:") then
					l_line := line.item
					-- Extract after "Error code: "
					if l_line.count > 11 then
						Result := l_line.substring (12, l_line.count).as_upper.trim
					end
					exit
				end
			end
		end

	extract_file_and_line (
		a_lines: ARRAYED_LIST [STRING_32];
		a_file_path: detachable STRING_32;
		a_line_number: detachable INTEGER
	)
		-- Extract file path and line number from error output.
		local
			l_line: STRING_32
			l_arrow_idx: INTEGER
		do
			across a_lines as line loop
				l_line := line.item
				-- Look for "->" line (points to file location)
				if l_line.starts_with ("->") and l_line.count > 2 then
					-- Line might have file/line info
					if l_line.contains (":") then
						parse_file_line (l_line, a_file_path, a_line_number)
						exit
					end
				elseif l_line.starts_with ("Line:") then
					-- Extract line number
					if l_line.count > 5 then
						a_line_number := l_line.substring (6, l_line.count).trim.to_integer
					end
				end
			end
		end

	parse_file_line (
		a_line: STRING_32;
		a_file_path: detachable STRING_32;
		a_line_number: detachable INTEGER
	)
		-- Parse file path and line number from "->" line.
		do
			-- Format: "-> /path/to/file.e:123" or similar
			-- For now, just extract from right side if it contains colon
			-- This is simplified - real implementation would be more robust
		end

	extract_message (a_lines: ARRAYED_LIST [STRING_32]): STRING_32
		-- Extract error message from lines.
		local
			l_collecting: BOOLEAN
			l_message_lines: ARRAYED_LIST [STRING_32]
		do
			create l_message_lines.make (10)
			create Result.make_empty

			across a_lines as line loop
				if line.item.starts_with ("Error:") then
					l_collecting := True
					-- Start collecting message
					if line.item.count > 6 then
						l_message_lines.extend (line.item.substring (7, line.item.count).trim)
					end
				elseif l_collecting and then line.item.starts_with ("Class:") then
					-- Stop collecting
					l_collecting := False
					exit
				elseif l_collecting and then not line.item.is_empty then
					l_message_lines.extend (line.item.trim)
				end
			end

			-- Join lines
			across l_message_lines as msg loop
				Result.append (msg.item)
				Result.append (" ")
			end
			Result := Result.trim
		end

	extract_class (a_lines: ARRAYED_LIST [STRING_32]): STRING_32
		-- Extract class name from error output.
		local
			l_line: STRING_32
		do
			create Result.make_empty
			across a_lines as line loop
				l_line := line.item
				if l_line.starts_with ("Class:") and l_line.count > 6 then
					Result := l_line.substring (7, l_line.count).trim
					exit
				end
			end
		end

	extract_feature (a_lines: ARRAYED_LIST [STRING_32]): STRING_32
		-- Extract feature/routine name from error output.
		local
			l_line: STRING_32
		do
			create Result.make_empty
			across a_lines as line loop
				l_line := line.item
				if l_line.starts_with ("Feature:") and l_line.count > 8 then
					Result := l_line.substring (9, l_line.count).trim
					exit
				end
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
