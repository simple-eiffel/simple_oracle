note
	description: "DbC metrics for a library"
	date: "$Date$"
	revision: "$Revision$"

class
	DBC_LIBRARY_METRICS

create
	make

feature {NONE} -- Initialization

	make (a_name, a_path: STRING)
			-- Create library metrics
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name
			path := a_path
		ensure
			name_set: name = a_name
		end

feature -- Access

	name: STRING
			-- Library name

	path: STRING
			-- Library path

	class_count: INTEGER
			-- Number of classes

	feature_count: INTEGER
			-- Number of features (non-attribute)

	require_count: INTEGER
			-- Features with preconditions

	ensure_count: INTEGER
			-- Features with postconditions

	invariant_count: INTEGER
			-- Classes with invariants

	score: INTEGER
			-- DbC score (0-100)

feature -- Modification

	increment_class_count
		do
			class_count := class_count + 1
		end

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

	increment_invariant_count
		do
			invariant_count := invariant_count + 1
		end

	calculate_score
			-- Calculate DbC score
		do
			if feature_count > 0 then
				score := ((require_count + ensure_count) * 50) // feature_count
				score := score.min (100)
			end
		end

end
