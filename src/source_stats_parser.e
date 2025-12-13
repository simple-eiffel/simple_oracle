note
	description: "[
		Source code statistics parser for Eiffel libraries.
		Simple line counting - strips notes, comments, blanks.
		Counts features as lines starting with lowercase + colon or paren at single-tab indent.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SOURCE_STATS_PARSER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize parser.
		do
			create class_names.make (100)
			create errors.make (10)
		end

feature -- Access

	class_count: INTEGER
			-- Number of classes found

	feature_count: INTEGER
			-- Number of features found

	attribute_count: INTEGER
			-- Number of attributes (features with type but no body on same line)

	lines_of_code: INTEGER
			-- Lines of actual code (excluding notes, comments, blanks)

	precondition_count: INTEGER
			-- Number of individual precondition assertion lines

	postcondition_count: INTEGER
			-- Number of individual postcondition assertion lines

	invariant_count: INTEGER
			-- Number of individual class invariant assertion lines

	class_names: ARRAYED_LIST [STRING_32]
			-- Class names found

	errors: ARRAYED_LIST [STRING_32]
			-- Parsing errors encountered

	is_parsed: BOOLEAN
			-- Has parsing completed successfully?

feature -- Parsing

	parse_source (a_src_path: READABLE_STRING_GENERAL)
			-- Parse all .e files in given source directory (recursive).
		require
			path_not_empty: not a_src_path.is_empty
		do
			-- Reset state
			class_count := 0
			feature_count := 0
			attribute_count := 0
			lines_of_code := 0
			precondition_count := 0
			postcondition_count := 0
			invariant_count := 0
			class_names.wipe_out
			errors.wipe_out
			is_parsed := False

			-- Parse recursively
			parse_directory (a_src_path)

			is_parsed := errors.is_empty
		end

feature {NONE} -- Implementation

	parse_directory (a_path: READABLE_STRING_GENERAL)
			-- Parse all .e files in directory recursively.
		local
			l_dir: SIMPLE_FILE
			l_file: SIMPLE_FILE
			l_content: STRING_32
			l_files: ARRAYED_LIST [STRING_32]
			l_dirs: ARRAYED_LIST [STRING_32]
			l_full_path: STRING_32
		do
			create l_dir.make (a_path)
			if l_dir.is_directory then
				-- Process .e files in this directory
				l_files := l_dir.files
				across l_files as ic loop
					if ic.ends_with (".e") then
						l_full_path := a_path.to_string_32 + "/" + ic
						create l_file.make (l_full_path)
						l_content := l_file.load
						if l_content /= Void and then not l_content.is_empty then
							parse_file_content (l_content)
						end
					end
				end

				-- Recurse into subdirectories
				l_dirs := l_dir.directories
				across l_dirs as ic loop
					l_full_path := a_path.to_string_32 + "/" + ic
					parse_directory (l_full_path)
				end
			end
		end

	parse_file_content (a_content: STRING_32)
			-- Count lines, classes, features, contracts. Skip notes, comments, blanks.
			-- Contract counting: count individual assertion lines within require/ensure blocks.
		local
			l_lines: LIST [STRING_32]
			l_line: STRING_32
			l_trimmed: STRING_32
			l_in_note: BOOLEAN
			l_in_feature_section: BOOLEAN
			l_in_precondition: BOOLEAN
			l_in_postcondition: BOOLEAN
			l_in_invariant: BOOLEAN
			l_class_name: detachable STRING_32
			l_first_char: CHARACTER_32
		do
			l_in_note := False
			l_in_feature_section := False
			l_in_precondition := False
			l_in_postcondition := False
			l_in_invariant := False
			l_lines := a_content.split ('%N')

			across l_lines as ic loop
				l_line := ic
				l_trimmed := l_line.twin
				l_trimmed.left_adjust
				l_trimmed.right_adjust

				-- Track note section (skip it)
				if l_trimmed.starts_with ("note") then
					l_in_note := True
				end

				-- Class declaration ends note section
				if l_trimmed.starts_with ("class") or l_trimmed.starts_with ("deferred class") or
				   l_trimmed.starts_with ("expanded class") or l_trimmed.starts_with ("frozen class") then
					l_in_note := False
					l_in_feature_section := False
					l_in_precondition := False
					l_in_postcondition := False
					class_count := class_count + 1
					l_class_name := extract_class_name (l_trimmed)
					if attached l_class_name then
						class_names.extend (l_class_name)
					end
				end

				-- Track feature sections
				if l_trimmed.starts_with ("feature") then
					l_in_feature_section := True
					l_in_precondition := False
					l_in_postcondition := False
				end

				-- Count features: single-tab indent, starts lowercase, has : or (
				if l_in_feature_section and l_line.count > 1 and then
				   l_line.item (1) = '%T' and then
				   (l_line.count < 2 or else l_line.item (2) /= '%T') then
					if l_trimmed.count > 0 then
						l_first_char := l_trimmed.item (1)
						if l_first_char >= 'a' and l_first_char <= 'z' then
							if l_trimmed.has (':') or l_trimmed.has ('(') then
								feature_count := feature_count + 1
								-- Attribute: has type (:) but no do/once/external/deferred
								if l_trimmed.has (':') and not l_trimmed.has_substring (" do") and
								   not l_trimmed.has_substring (" once") and
								   not l_trimmed.has_substring (" external") and
								   not l_trimmed.has_substring (" deferred") then
									attribute_count := attribute_count + 1
								end
							end
						end
					end
				end

				-- Track contract blocks and count individual assertion lines
				-- Enter precondition block
				if l_trimmed.starts_with ("require") then
					l_in_precondition := True
					l_in_postcondition := False
				-- Enter postcondition block
				elseif l_trimmed.starts_with ("ensure") then
					l_in_postcondition := True
					l_in_precondition := False
				-- Enter invariant block (class invariant)
				elseif l_trimmed.same_string ("invariant") then
					l_in_invariant := True
					l_in_precondition := False
					l_in_postcondition := False
				-- Exit precondition block (local, do, once, deferred, external, attribute)
				elseif l_in_precondition and (
					l_trimmed.same_string ("local") or
					l_trimmed.same_string ("do") or
					l_trimmed.same_string ("once") or
					l_trimmed.same_string ("deferred") or
					l_trimmed.starts_with ("external") or
					l_trimmed.same_string ("attribute")) then
					l_in_precondition := False
				-- Exit postcondition block (end, rescue)
				elseif l_in_postcondition and (
					l_trimmed.same_string ("end") or
					l_trimmed.same_string ("rescue")) then
					l_in_postcondition := False
				-- Exit invariant on end
				elseif l_in_invariant and l_trimmed.same_string ("end") then
					l_in_invariant := False
				-- Count assertion lines within contract blocks
				elseif l_in_precondition and not l_trimmed.is_empty and not l_trimmed.starts_with ("--") then
					precondition_count := precondition_count + 1
				elseif l_in_postcondition and not l_trimmed.is_empty and not l_trimmed.starts_with ("--") then
					postcondition_count := postcondition_count + 1
				elseif l_in_invariant and not l_trimmed.is_empty and not l_trimmed.starts_with ("--") then
					invariant_count := invariant_count + 1
				end

				-- Count line if it's not: in note section, comment, or blank
				if not l_in_note and not l_trimmed.is_empty and not l_trimmed.starts_with ("--") then
					lines_of_code := lines_of_code + 1
				end
			end
		end

	extract_class_name (a_line: STRING_32): detachable STRING_32
			-- Extract class name from class declaration line.
		local
			l_parts: LIST [STRING_32]
			l_name: STRING_32
			i: INTEGER
			c: CHARACTER_32
			l_valid: BOOLEAN
		do
			l_parts := a_line.split (' ')
			across l_parts as ic loop
				l_name := ic
				l_name.left_adjust
				l_name.right_adjust
				if l_name.count >= 2 then
					l_valid := True
					from i := 1 until i > l_name.count or not l_valid loop
						c := l_name.item (i)
						if not ((c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c = '_') then
							l_valid := False
						end
						i := i + 1
					end
					if l_valid and then l_name.item (1) >= 'A' and then l_name.item (1) <= 'Z' then
						if not l_name.same_string ("NONE") and not l_name.same_string ("ANY") then
							Result := l_name
						end
					end
				end
			end
		end

invariant
	class_names_attached: class_names /= Void
	errors_attached: errors /= Void

end
