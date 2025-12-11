note
	description: "DbC metrics for a class"
	date: "$Date$"
	revision: "$Revision$"

class
	DBC_CLASS_METRICS

create
	make

feature {NONE} -- Initialization

	make (a_lib_name, a_class_name, a_file_path: STRING)
			-- Create class metrics
		require
			lib_not_empty: not a_lib_name.is_empty
			class_not_empty: not a_class_name.is_empty
		do
			library_name := a_lib_name
			class_name := a_class_name
			file_path := a_file_path
		ensure
			lib_set: library_name = a_lib_name
			class_set: class_name = a_class_name
		end

feature -- Access

	library_name: STRING
			-- Owning library

	class_name: STRING
			-- Class name

	file_path: STRING
			-- Source file path

	feature_count: INTEGER
			-- Number of features

	require_count: INTEGER
			-- Features with preconditions

	ensure_count: INTEGER
			-- Features with postconditions

	has_invariant: BOOLEAN
			-- Does class have invariant?

	score: INTEGER
			-- DbC score (0-100)

feature -- Modification

	increment_feature_count
		do
			feature_count := feature_count + 1
		end

	increment_require_count
		do
			require_count := require_count + 1
		end

	increment_ensure_count
		do
			ensure_count := ensure_count + 1
		end

	set_has_invariant (a_value: BOOLEAN)
		do
			has_invariant := a_value
		end

	calculate_score
			-- Calculate DbC score
			-- Invariant bonus: +20% if present
		local
			l_base_score: INTEGER
		do
			if feature_count > 0 then
				l_base_score := ((require_count + ensure_count) * 50) // feature_count
			end
			if has_invariant then
				score := ((l_base_score * 120) // 100).min (100)
			else
				score := l_base_score.min (100)
			end
		end

end
