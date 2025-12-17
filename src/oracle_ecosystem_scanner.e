note
	description: "[
		ORACLE_ECOSYSTEM_SCANNER - Scans and indexes the simple_* ecosystem.

		Parses .e files to extract class and feature information.
		Uses simple text parsing (regex patterns) for speed.

		Architecture:
		- Scans $SIMPLE_EIFFEL/simple_* directories
		- Parses .e files for class declarations and features
		- Stores results in oracle database
		- Can run on SCOOP processor for background updates

		Usage:
			scanner: ORACLE_ECOSYSTEM_SCANNER
			create scanner.make (oracle)
			scanner.scan_ecosystem (env.item ("SIMPLE_EIFFEL"))
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	ORACLE_ECOSYSTEM_SCANNER

create
	make

feature {NONE} -- Initialization

	make (a_oracle: SIMPLE_ORACLE)
			-- Create scanner with oracle reference.
		require
			oracle_ready: a_oracle.is_ready
		do
			oracle := a_oracle
			create libraries_found.make (50)
			create classes_found.make (200)
			create features_found.make (1000)
			create parents_found.make (500)
			create clients_found.make (2000)
		end

feature -- Access

	oracle: SIMPLE_ORACLE
			-- Oracle to store results.

	libraries_found: ARRAYED_LIST [TUPLE [name, path, description: STRING_32]]
			-- Libraries discovered during scan.

	classes_found: ARRAYED_LIST [TUPLE [library, name, file_path, description: STRING_32; feature_count: INTEGER; file_modified: INTEGER_64]]
			-- Classes discovered during scan.
			-- file_modified = Unix timestamp of .e file last modification.

	features_found: ARRAYED_LIST [TUPLE [library, class_name, feature_name, signature, comment, preconditions, postconditions: STRING_32; is_query: BOOLEAN]]
			-- Features discovered during scan.
			-- Includes:
			--   comment = feature header comment (what it does)
			--   preconditions = require clause (how to use it)
			--   postconditions = ensure clause (what it promises)

	parents_found: ARRAYED_LIST [TUPLE [library, class_name, parent_name, rename_clause, redefine_clause: STRING_32]]
			-- Inheritance relationships discovered during scan.
			-- Each entry: class_name inherits from parent_name.

	clients_found: ARRAYED_LIST [TUPLE [library, client_class, supplier_name, usage_type: STRING_32]]
			-- Client/supplier relationships discovered during scan.
			-- usage_type: "attribute", "local", "argument", "creation"

	last_scan_time: INTEGER
			-- Seconds taken by last scan.

	incremental_mode: BOOLEAN
			-- Is incremental scanning enabled?
			-- When True, only scan files modified since last scan.

feature -- Scanning

	scan_ecosystem (a_root_path: READABLE_STRING_GENERAL)
			-- Scan all simple_* directories under root path.
			-- Full scan: re-parses all files.
		require
			path_not_empty: not a_root_path.is_empty
		local
			l_dir: DIRECTORY
			l_path: PATH
			l_start, l_end: SIMPLE_DATE_TIME
		do
			create l_start.make_now
			libraries_found.wipe_out
			classes_found.wipe_out
			features_found.wipe_out
			parents_found.wipe_out
			clients_found.wipe_out

			create l_dir.make_with_name (a_root_path.to_string_32)
			if l_dir.exists then
				l_dir.open_read
				across l_dir.linear_representation as entry loop
					if entry.starts_with ("simple_") then
						create l_path.make_from_string (a_root_path.to_string_32 + "\" + entry)
						scan_library (l_path.name, entry.to_string_32)
					end
				end
			end

			-- Store results
			store_scan_results

			-- Calculate elapsed time
			create l_end.make_now
			last_scan_time := (l_end.to_timestamp - l_start.to_timestamp).to_integer_32
		end

	set_incremental (a_enabled: BOOLEAN)
			-- Enable or disable incremental scanning.
		do
			incremental_mode := a_enabled
		ensure
			set: incremental_mode = a_enabled
		end

	scan_from_ucf (a_ucf: SIMPLE_UCF)
			-- Scan libraries defined in UCF configuration.
			-- More precise than directory scan - only scans libraries explicitly defined.
		require
			ucf_valid: a_ucf.is_valid
		local
			l_start, l_end: SIMPLE_DATE_TIME
		do
			create l_start.make_now
			libraries_found.wipe_out
			classes_found.wipe_out
			features_found.wipe_out
			parents_found.wipe_out
			clients_found.wipe_out

			across a_ucf.libraries as lib loop
				if not lib.resolved_path.is_empty then
					scan_library (lib.resolved_path.to_string_8, lib.name.to_string_32)
				end
			end

			-- Store results
			store_scan_results

			-- Calculate elapsed time
			create l_end.make_now
			last_scan_time := (l_end.to_timestamp - l_start.to_timestamp).to_integer_32
		end

	scan_from_environment
			-- Scan libraries discovered from SIMPLE_* environment variables.
			-- Uses UCF auto-discovery for consistency.
		local
			l_ucf: SIMPLE_UCF
		do
			create l_ucf.make
			l_ucf.discover_from_environment
			if l_ucf.is_valid then
				scan_from_ucf (l_ucf)
			end
		end

	scan_library (a_path: READABLE_STRING_GENERAL; a_name: STRING_32)
			-- Scan a single library directory.
		local
			l_dir: DIRECTORY
			l_src_path: PATH
			l_description: STRING_32
		do
			-- Get description from README if exists
			l_description := read_library_description (a_path)
			libraries_found.extend ([a_name, a_path.to_string_32, l_description])

			-- Scan src directory for .e files
			create l_src_path.make_from_string (a_path.to_string_32 + "\src")
			create l_dir.make_with_name (l_src_path.name)
			if l_dir.exists then
				scan_directory_for_classes (l_dir, a_name)
			end
		end

	scan_directory_for_classes (a_dir: DIRECTORY; a_library: STRING_32)
			-- Recursively scan directory for .e files.
		local
			l_path: PATH
			l_subdir: DIRECTORY
		do
			a_dir.open_read
			across a_dir.linear_representation as entry loop
				if not entry.starts_with (".") then
					create l_path.make_from_string (a_dir.path.name.to_string_32 + "\" + entry)
					if entry.ends_with (".e") then
						parse_eiffel_file (l_path.name, a_library)
					else
						-- Check if subdirectory
						create l_subdir.make_with_name (l_path.name)
						if l_subdir.exists then
							scan_directory_for_classes (l_subdir, a_library)
						end
					end
				end
			end
		end

feature {NONE} -- Parsing

	parse_eiffel_file (a_file_path: READABLE_STRING_GENERAL; a_library: STRING_32)
			-- Parse an Eiffel .e file for class and feature info.
			-- Extracts: class name, description, features, inheritance, clients.
		local
			l_file: PLAIN_TEXT_FILE
			l_content: STRING_32
			l_class_name, l_description: STRING_32
			l_feature_count: INTEGER
			l_file_modified: INTEGER_64
		do
			create l_file.make_with_name (a_file_path.to_string_32)
			if l_file.exists and then l_file.is_readable then
				-- Get file modification timestamp
				l_file_modified := l_file.date.to_integer_64

				l_file.open_read
				create l_content.make (l_file.count.to_integer_32)
				from
				until
					l_file.end_of_file
				loop
					l_file.read_line
					l_content.append (l_file.last_string)
					l_content.append_character ('%N')
				end
				l_file.close

				-- Extract class name
				l_class_name := extract_class_name (l_content)
				if not l_class_name.is_empty then
					-- Extract description
					l_description := extract_class_description (l_content)

					-- Extract and count features
					l_feature_count := extract_features (l_content, a_library, l_class_name)

					-- Extract inheritance relationships (Phase 3)
					extract_inheritance (l_content, a_library, l_class_name)

					-- Extract client/supplier relationships (Phase 3)
					extract_clients (l_content, a_library, l_class_name)

					-- Add to found classes with file timestamp
					classes_found.extend ([a_library, l_class_name, a_file_path.to_string_32, l_description, l_feature_count, l_file_modified])
				end
			end
		end

	extract_class_name (a_content: STRING_32): STRING_32
			-- Extract class name from Eiffel source.
			-- Looks for "class NAME" pattern.
		local
			i, j: INTEGER
		do
			create Result.make_empty
			-- Find "class " keyword
			i := a_content.substring_index ("class%N%T", 1)
			if i = 0 then
				i := a_content.substring_index ("class ", 1)
			end
			if i > 0 then
				-- Skip "class" and whitespace
				from
					i := i + 5
				until
					i > a_content.count or else not a_content.item (i).is_space
				loop
					i := i + 1
				end
				-- Read class name (until whitespace or newline)
				from
					j := i
				until
					j > a_content.count or else a_content.item (j).is_space or else a_content.item (j) = '%N'
				loop
					j := j + 1
				end
				if j > i then
					Result := a_content.substring (i, j - 1)
					Result.to_upper
				end
			end
		end

	extract_class_description (a_content: STRING_32): STRING_32
			-- Extract description from note clause.
		local
			i, j: INTEGER
		do
			create Result.make_empty
			-- Find description: "[
			i := a_content.substring_index ("description: %"[", 1)
			if i > 0 then
				i := i + 15 -- Skip past description: "[
				j := a_content.substring_index ("]%"", i)
				if j > i then
					Result := a_content.substring (i, j - 1)
					Result.left_adjust
					Result.right_adjust
					-- Take first line only
					i := Result.index_of ('%N', 1)
					if i > 0 then
						Result := Result.substring (1, i - 1)
					end
					-- Limit length
					if Result.count > 200 then
						Result := Result.substring (1, 200) + "..."
					end
				end
			else
				-- Try simpler description: "text"
				i := a_content.substring_index ("description: %"", 1)
				if i > 0 then
					i := i + 14
					j := a_content.index_of ('%"', i)
					if j > i then
						Result := a_content.substring (i, j - 1)
						if Result.count > 200 then
							Result := Result.substring (1, 200) + "..."
						end
					end
				end
			end
		end

	extract_features (a_content: STRING_32; a_library, a_class_name: STRING_32): INTEGER
			-- Extract features from Eiffel source and add to features_found.
			-- Includes DBC contracts (require/ensure).
			-- Returns count of features found.
		local
			i, j, k, l_feat_start: INTEGER
			l_line: STRING_32
			l_feature_name, l_signature, l_comment, l_preconditions, l_postconditions: STRING_32
			l_is_query: BOOLEAN
			l_in_feature_section: BOOLEAN
			l_lines: LIST [STRING_32]
		do
			l_lines := a_content.split ('%N')
			across l_lines as line loop
				l_line := line.to_string_32
				l_line.left_adjust

				-- Check for feature section
				if l_line.starts_with ("feature") then
					l_in_feature_section := True
				elseif l_line.starts_with ("invariant") or l_line.same_string ("end") then
					l_in_feature_section := False
				elseif l_in_feature_section then
					-- Look for feature declarations
					-- Pattern: name: TYPE or name (args): TYPE or name (args)
					i := l_line.index_of (':', 1)
					j := l_line.index_of ('(', 1)

					if i > 1 and (j = 0 or i < j) then
						-- Query: name: TYPE
						l_feature_name := l_line.substring (1, i - 1)
						l_feature_name.right_adjust
						if is_valid_feature_name (l_feature_name) then
							l_is_query := True
							k := l_line.index_of ('%N', i)
							if k = 0 then k := l_line.count + 1 end
							l_signature := l_line.substring (1, (k - 1).min (l_line.count))

							-- Extract feature documentation
							l_feat_start := a_content.substring_index (l_line, 1)
							l_comment := extract_feature_comment (a_content, l_feat_start)
							l_preconditions := extract_require_clause (a_content, l_feat_start)
							l_postconditions := extract_ensure_clause (a_content, l_feat_start)

							features_found.extend ([a_library, a_class_name, l_feature_name, l_signature, l_comment, l_preconditions, l_postconditions, l_is_query])
							Result := Result + 1
						end
					elseif j > 1 then
						-- Command or query with args: name (args) or name (args): TYPE
						l_feature_name := l_line.substring (1, j - 1)
						l_feature_name.right_adjust
						if is_valid_feature_name (l_feature_name) then
							l_is_query := l_line.has (':')
							k := l_line.count
							l_signature := l_line.substring (1, k.min (100))

							-- Extract feature documentation
							l_feat_start := a_content.substring_index (l_line, 1)
							l_comment := extract_feature_comment (a_content, l_feat_start)
							l_preconditions := extract_require_clause (a_content, l_feat_start)
							l_postconditions := extract_ensure_clause (a_content, l_feat_start)

							features_found.extend ([a_library, a_class_name, l_feature_name, l_signature, l_comment, l_preconditions, l_postconditions, l_is_query])
							Result := Result + 1
						end
					end
				end
			end
		end

	extract_feature_comment (a_content: STRING_32; a_start: INTEGER): STRING_32
			-- Extract feature header comment (what it does).
			-- Looks for -- comment lines after feature declaration.
			-- Supports multi-line comments.
		local
			i, j: INTEGER
			l_in_comment: BOOLEAN
		do
			create Result.make_empty
			-- Find the feature line position in original content
			-- Look for comment lines immediately following (starting with --)
			i := a_start
			-- Skip the feature declaration line
			j := a_content.index_of ('%N', i)
			if j > 0 then
				i := j + 1
				l_in_comment := True -- Start looking for comments
				-- Now look for comment lines
				from
				until
					i > a_content.count or not l_in_comment
				loop
					-- Skip whitespace
					from
					until
						i > a_content.count or else not a_content.item (i).is_space
					loop
						if a_content.item (i) = '%N' then
							-- End of line without comment
							l_in_comment := Result.is_empty -- Only continue if no comment yet
						end
						i := i + 1
					end

					if i <= a_content.count then
						-- Check for comment marker --
						if i + 1 <= a_content.count and then
							a_content.item (i) = '-' and then a_content.item (i + 1) = '-'
						then
							-- Found a comment line
							i := i + 2 -- Skip --
							-- Skip space after --
							if i <= a_content.count and then a_content.item (i) = ' ' then
								i := i + 1
							end
							-- Read to end of line
							j := a_content.index_of ('%N', i)
							if j = 0 then j := a_content.count + 1 end
							if j > i then
								if not Result.is_empty then
									Result.append (" ")
								end
								Result.append (a_content.substring (i, j - 1))
							end
							i := j + 1
							l_in_comment := True -- Continue looking for more comment lines
						else
							l_in_comment := False -- Not a comment, stop
						end
					end
				end
			end
			-- Limit length
			if Result.count > 500 then
				Result := Result.substring (1, 500) + "..."
			end
		end

	extract_require_clause (a_content: STRING_32; a_start: INTEGER): STRING_32
			-- Extract require clause after position.
			-- Returns preconditions (how to use this feature).
		local
			i, j: INTEGER
		do
			create Result.make_empty
			-- Find "require" after feature start (within reasonable range)
			i := a_content.substring_index ("%N%T%Trequire", a_start)
			if i > 0 and i < a_start + 500 then
				i := i + 10 -- Skip past "require"
				-- Find end (do, local, or next require/ensure)
				j := a_content.substring_index ("%N%T%Tdo", i)
				if j = 0 or j > i + 500 then
					j := a_content.substring_index ("%N%T%Tlocal", i)
				end
				if j > i and j < i + 500 then
					Result := a_content.substring (i, j - 1)
					Result := clean_contract_text (Result)
				end
			end
		end

	extract_ensure_clause (a_content: STRING_32; a_start: INTEGER): STRING_32
			-- Extract ensure clause after position.
			-- Returns postconditions (what this feature promises).
		local
			i, j: INTEGER
		do
			create Result.make_empty
			-- Find "ensure" after feature start (within reasonable range)
			i := a_content.substring_index ("%N%T%Tensure", a_start)
			if i > 0 and i < a_start + 2000 then
				i := i + 10 -- Skip past "ensure"
				-- Find end marker
				j := a_content.substring_index ("%N%T%Tend", i)
				if j > i and j < i + 500 then
					Result := a_content.substring (i, j - 1)
					Result := clean_contract_text (Result)
				end
			end
		end

	clean_contract_text (a_text: STRING_32): STRING_32
			-- Clean up contract text for storage.
		local
			l_lines: LIST [STRING_32]
			l_line: STRING_32
		do
			create Result.make (a_text.count)
			l_lines := a_text.split ('%N')
			across l_lines as line loop
				l_line := line.to_string_32
				l_line.left_adjust
				l_line.right_adjust
				if not l_line.is_empty and not l_line.starts_with ("--") then
					if not Result.is_empty then
						Result.append ("; ")
					end
					Result.append (l_line)
				end
			end
			-- Limit length
			if Result.count > 500 then
				Result := Result.substring (1, 500) + "..."
			end
		end

	is_valid_feature_name (a_name: STRING_32): BOOLEAN
			-- Is this a valid Eiffel feature name?
		do
			Result := not a_name.is_empty
				and then a_name.item (1).is_alpha
				and then not a_name.has_substring ("--")
				and then not a_name.same_string ("do")
				and then not a_name.same_string ("local")
				and then not a_name.same_string ("require")
				and then not a_name.same_string ("ensure")
				and then not a_name.same_string ("if")
				and then not a_name.same_string ("then")
				and then not a_name.same_string ("else")
				and then not a_name.same_string ("from")
				and then not a_name.same_string ("until")
				and then not a_name.same_string ("loop")
		end

	extract_inheritance (a_content: STRING_32; a_library, a_class_name: STRING_32)
			-- Extract inherit clause and add to parents_found.
			-- Parses: inherit PARENT [redefine x, y rename a as b end]
		local
			i, j, k: INTEGER
			l_inherit_section: STRING_32
			l_parent, l_rename, l_redefine: STRING_32
			l_lines: LIST [STRING_32]
			l_line: STRING_32
		do
			-- Find inherit keyword
			i := a_content.substring_index ("%Ninherit%N", 1)
			if i = 0 then
				i := a_content.substring_index ("%Ninherit%T", 1)
			end
			if i > 0 then
				i := i + 8 -- Skip past "inherit"
				-- Find end of inherit section (next keyword: create, feature, end)
				j := a_content.substring_index ("%Ncreate%N", i)
				if j = 0 then j := a_content.substring_index ("%Ncreate%T", i) end
				if j = 0 then j := a_content.substring_index ("%Nfeature%N", i) end
				if j = 0 then j := a_content.substring_index ("%Nfeature ", i) end
				if j = 0 or j > i + 2000 then j := (i + 2000).min (a_content.count) end

				if j > i then
					l_inherit_section := a_content.substring (i, j - 1)
					-- Parse each parent
					l_lines := l_inherit_section.split ('%N')
					create l_rename.make_empty
					create l_redefine.make_empty
					across l_lines as line loop
						l_line := line.to_string_32
						l_line.left_adjust
						l_line.right_adjust

						-- Skip empty lines and comments
						if not l_line.is_empty and not l_line.starts_with ("--") then
							-- Check for parent name (starts with uppercase, may have {NONE})
							if l_line.item (1).is_upper or l_line.starts_with ("{") then
								-- Extract parent name
								l_parent := extract_parent_name (l_line)
								if not l_parent.is_empty then
									-- Extract redefine clause if present
									l_redefine := extract_adapt_clause (l_line, "redefine")
									-- Extract rename clause if present
									l_rename := extract_adapt_clause (l_line, "rename")
									parents_found.extend ([a_library, a_class_name, l_parent, l_rename, l_redefine])
								end
							elseif l_line.starts_with ("redefine") then
								-- Multi-line redefine
								l_redefine := l_line.substring (9, l_line.count)
								l_redefine.left_adjust
							elseif l_line.starts_with ("rename") then
								-- Multi-line rename
								l_rename := l_line.substring (7, l_line.count)
								l_rename.left_adjust
							end
						end
					end
				end
			end
		end

	extract_parent_name (a_line: STRING_32): STRING_32
			-- Extract parent class name from inherit line.
			-- Handles: PARENT, {NONE} PARENT, PARENT [G]
		local
			i, j: INTEGER
		do
			create Result.make_empty
			-- Skip export clause {NONE} or {ANY}
			i := 1
			if a_line.item (1) = '{' then
				i := a_line.index_of ('}', 1)
				if i > 0 then
					i := i + 1
					-- Skip whitespace after }
					from until i > a_line.count or else not a_line.item (i).is_space loop
						i := i + 1
					end
				else
					i := 1
				end
			end

			-- Find end of class name (space, [, newline, or end of string)
			if i <= a_line.count and then a_line.item (i).is_upper then
				from j := i until j > a_line.count or else
					(not a_line.item (j).is_alpha_numeric and a_line.item (j) /= '_')
				loop
					j := j + 1
				end
				if j > i then
					Result := a_line.substring (i, j - 1)
					Result.to_upper
				end
			end
		end

	extract_adapt_clause (a_line: STRING_32; a_keyword: STRING): STRING_32
			-- Extract adaptation clause (redefine/rename/etc) from line.
		local
			i, j: INTEGER
		do
			create Result.make_empty
			i := a_line.substring_index (a_keyword, 1)
			if i > 0 then
				i := i + a_keyword.count
				-- Find end (next keyword or end)
				j := a_line.substring_index (" end", i)
				if j = 0 then j := a_line.count + 1 end
				if j > i then
					Result := a_line.substring (i, j - 1)
					Result.left_adjust
					Result.right_adjust
					-- Limit length
					if Result.count > 200 then
						Result := Result.substring (1, 200) + "..."
					end
				end
			end
		end

	extract_clients (a_content: STRING_32; a_library, a_class_name: STRING_32)
			-- Extract client/supplier relationships.
			-- Finds type references in: attributes, locals, arguments, create statements.
		local
			l_lines: LIST [STRING_32]
			l_line, l_type: STRING_32
			l_in_feature: BOOLEAN
			i: INTEGER
		do
			l_lines := a_content.split ('%N')
			across l_lines as line loop
				l_line := line.to_string_32
				l_line.left_adjust

				-- Track feature sections
				if l_line.starts_with ("feature") then
					l_in_feature := True
				elseif l_line.starts_with ("invariant") or l_line.same_string ("end") then
					l_in_feature := False
				end

				-- Look for type declarations
				if l_in_feature then
					-- Attribute: name: TYPE
					i := l_line.index_of (':', 1)
					if i > 1 then
						l_type := extract_type_from_declaration (l_line.substring (i + 1, l_line.count))
						if is_valid_type_name (l_type) then
							add_client_if_new (a_library, a_class_name, l_type, "attribute")
						end
					end

					-- Local variables: local ... name: TYPE
					if l_line.starts_with ("local") or (l_line.index_of (':', 1) > 0 and l_line.count < 80) then
						l_type := extract_type_from_declaration (l_line)
						if is_valid_type_name (l_type) then
							add_client_if_new (a_library, a_class_name, l_type, "local")
						end
					end

					-- Creation: create {TYPE}.make or create x.make
					if l_line.has_substring ("create ") or l_line.has_substring ("create%T") then
						l_type := extract_type_from_create (l_line)
						if is_valid_type_name (l_type) then
							add_client_if_new (a_library, a_class_name, l_type, "creation")
						end
					end
				end
			end
		end

	extract_type_from_declaration (a_text: STRING_32): STRING_32
			-- Extract type name from declaration text.
			-- Handles: TYPE, detachable TYPE, GENERIC [G], etc.
		local
			i, j: INTEGER
			l_text: STRING_32
		do
			create Result.make_empty
			l_text := a_text.twin
			l_text.left_adjust

			-- Skip "detachable" or "attached"
			if l_text.starts_with ("detachable ") then
				l_text := l_text.substring (12, l_text.count)
				l_text.left_adjust
			elseif l_text.starts_with ("attached ") then
				l_text := l_text.substring (10, l_text.count)
				l_text.left_adjust
			end

			-- Find type name (uppercase identifier)
			if not l_text.is_empty and then l_text.item (1).is_upper then
				from i := 1 until i > l_text.count or else
					(not l_text.item (i).is_alpha_numeric and l_text.item (i) /= '_')
				loop
					i := i + 1
				end
				if i > 1 then
					Result := l_text.substring (1, i - 1)
					Result.to_upper
				end
			end
		end

	extract_type_from_create (a_line: STRING_32): STRING_32
			-- Extract type from create statement.
			-- Handles: create {TYPE}.make, create x.make
		local
			i, j: INTEGER
		do
			create Result.make_empty
			-- Look for {TYPE} pattern
			i := a_line.index_of ('{', 1)
			if i > 0 then
				j := a_line.index_of ('}', i)
				if j > i + 1 then
					Result := a_line.substring (i + 1, j - 1)
					Result.to_upper
				end
			end
		end

	is_valid_type_name (a_name: STRING_32): BOOLEAN
			-- Is this a valid type name worth tracking as a client?
		do
			Result := not a_name.is_empty
				and then a_name.item (1).is_upper
				and then a_name.count > 1
				-- Exclude common base types
				and then not a_name.same_string ("INTEGER")
				and then not a_name.same_string ("INTEGER_32")
				and then not a_name.same_string ("INTEGER_64")
				and then not a_name.same_string ("NATURAL")
				and then not a_name.same_string ("NATURAL_32")
				and then not a_name.same_string ("NATURAL_64")
				and then not a_name.same_string ("REAL")
				and then not a_name.same_string ("REAL_32")
				and then not a_name.same_string ("REAL_64")
				and then not a_name.same_string ("DOUBLE")
				and then not a_name.same_string ("BOOLEAN")
				and then not a_name.same_string ("CHARACTER")
				and then not a_name.same_string ("CHARACTER_8")
				and then not a_name.same_string ("CHARACTER_32")
				and then not a_name.same_string ("POINTER")
				and then not a_name.same_string ("ANY")
				and then not a_name.same_string ("NONE")
		end

	add_client_if_new (a_library, a_client, a_supplier, a_usage: STRING_32)
			-- Add client relationship if not already present.
		local
			l_exists: BOOLEAN
		do
			across clients_found as c loop
				if c.client_class.same_string (a_client) and c.supplier_name.same_string (a_supplier) then
					l_exists := True
				end
			end
			if not l_exists then
				clients_found.extend ([a_library, a_client, a_supplier, a_usage])
			end
		end

	read_library_description (a_path: READABLE_STRING_GENERAL): STRING_32
			-- Read library description from README.md.
		local
			l_file: PLAIN_TEXT_FILE
			l_readme_path: STRING_32
		do
			create Result.make_empty
			l_readme_path := a_path.to_string_32 + "\README.md"
			create l_file.make_with_name (l_readme_path)
			if l_file.exists and then l_file.is_readable then
				l_file.open_read
				-- Read first few lines
				from
				until
					l_file.end_of_file or Result.count > 200
				loop
					l_file.read_line
					if not l_file.last_string.starts_with ("#") and not l_file.last_string.is_empty then
						Result.append (l_file.last_string)
						Result.append (" ")
					end
				end
				l_file.close
				Result.right_adjust
				if Result.count > 200 then
					Result := Result.substring (1, 200) + "..."
				end
			end
		end

feature {NONE} -- Storage

	store_scan_results
			-- Store scan results in oracle database.
			-- Stores: libraries, classes (with timestamps), features, parents, clients.
		do
			io.put_string ("  [store] Starting database storage...%N")
			if attached oracle.disk_db as db then
				io.put_string ("  [store] Got disk_db, beginning transaction...%N")
				db.run_sql ("BEGIN TRANSACTION")

				io.put_string ("  [store] Storing " + libraries_found.count.out + " libraries...%N")
				-- Store libraries (INSERT OR REPLACE handles updates)
				across libraries_found as lib loop
					db.run_sql_with (
						"INSERT OR REPLACE INTO libraries (name, path, description, last_seen) VALUES (?, ?, ?, datetime('now'))",
						<<lib.name, lib.path, lib.description>>
					)
				end

				-- Clear all old relationship data (Phase 3)
				db.run_sql (
					"DELETE FROM class_parents WHERE class_id IN " +
					"(SELECT c.id FROM classes c JOIN libraries l ON c.library_id = l.id WHERE l.name LIKE 'simple_%%')"
				)
				db.run_sql (
					"DELETE FROM class_clients WHERE client_class_id IN " +
					"(SELECT c.id FROM classes c JOIN libraries l ON c.library_id = l.id WHERE l.name LIKE 'simple_%%')"
				)

				-- Clear all old feature data
				db.run_sql (
					"DELETE FROM features WHERE class_id IN " +
					"(SELECT c.id FROM classes c JOIN libraries l ON c.library_id = l.id WHERE l.name LIKE 'simple_%%')"
				)

				-- Clear all old class data
				db.run_sql (
					"DELETE FROM classes WHERE library_id IN (SELECT id FROM libraries WHERE name LIKE 'simple_%%')"
				)

				io.put_string ("  [store] Storing " + classes_found.count.out + " classes...%N")
				-- Store classes with file timestamp
				across classes_found as cls loop
					db.run_sql_with (
						"INSERT INTO classes (library_id, name, file_path, description, feature_count, file_modified) " +
						"SELECT id, ?, ?, ?, ?, ? FROM libraries WHERE name = ?",
						<<cls.name, cls.file_path, cls.description, cls.feature_count, cls.file_modified, cls.library>>
					)
				end

				io.put_string ("  [store] Storing " + features_found.count.out + " features...%N")
				-- Store features with DBC contracts
				across features_found as feat loop
					db.run_sql_with (
						"INSERT INTO features (class_id, name, signature, preconditions, postconditions, is_query, description) " +
						"SELECT c.id, ?, ?, ?, ?, ?, ? FROM classes c JOIN libraries l ON c.library_id = l.id " +
						"WHERE l.name = ? AND c.name = ?",
						<<feat.feature_name, feat.signature, feat.preconditions, feat.postconditions, feat.is_query, feat.comment, feat.library, feat.class_name>>
					)
				end

				io.put_string ("  [store] Storing " + parents_found.count.out + " inheritance relationships...%N")
				-- Store inheritance relationships (Phase 3)
				across parents_found as par loop
					db.run_sql_with (
						"INSERT OR IGNORE INTO class_parents (class_id, parent_name, rename_clause, redefine_clause) " +
						"SELECT c.id, ?, ?, ? FROM classes c JOIN libraries l ON c.library_id = l.id " +
						"WHERE l.name = ? AND c.name = ?",
						<<par.parent_name, par.rename_clause, par.redefine_clause, par.library, par.class_name>>
					)
				end

				io.put_string ("  [store] Storing " + clients_found.count.out + " client relationships...%N")
				-- Store client/supplier relationships (Phase 3)
				across clients_found as cli loop
					db.run_sql_with (
						"INSERT OR IGNORE INTO class_clients (client_class_id, supplier_name, usage_type) " +
						"SELECT c.id, ?, ? FROM classes c JOIN libraries l ON c.library_id = l.id " +
						"WHERE l.name = ? AND c.name = ?",
						<<cli.supplier_name, cli.usage_type, cli.library, cli.client_class>>
					)
				end

				io.put_string ("  [store] Committing transaction...%N")
				db.run_sql ("COMMIT")
				io.put_string ("  [store] Done.%N")
			else
				io.put_string ("  [store] ERROR: disk_db not attached%N")
			end
		end

feature -- Reports

	library_count: INTEGER
			-- Number of libraries found.
		do
			Result := libraries_found.count
		end

	class_count: INTEGER
			-- Number of classes found.
		do
			Result := classes_found.count
		end

	feature_count: INTEGER
			-- Number of features found.
		do
			Result := features_found.count
		end

	summary: STRING_32
			-- Summary of scan results.
		do
			create Result.make (500)
			Result.append ("Ecosystem Scan Summary%N")
			Result.append ("======================%N")
			Result.append ("Libraries: ")
			Result.append (library_count.out)
			Result.append ("%NClasses: ")
			Result.append (class_count.out)
			Result.append ("%NFeatures: ")
			Result.append (feature_count.out)
			Result.append ("%NInheritance links: ")
			Result.append (parents_found.count.out)
			Result.append ("%NClient relationships: ")
			Result.append (clients_found.count.out)
			Result.append ("%NScan time: ")
			Result.append (last_scan_time.out)
			Result.append ("s%N")
		end

	parent_count: INTEGER
			-- Number of inheritance relationships found.
		do
			Result := parents_found.count
		end

	client_count: INTEGER
			-- Number of client relationships found.
		do
			Result := clients_found.count
		end

end
