note
	description: "DbC metrics for a feature"
	date: "$Date$"
	revision: "$Revision$"

class
	DBC_FEATURE_METRICS

create
	make

feature {NONE} -- Initialization

	make (a_lib_name, a_class_name, a_feature_name: STRING)
			-- Create feature metrics
		require
			lib_not_empty: not a_lib_name.is_empty
			class_not_empty: not a_class_name.is_empty
			feature_not_empty: not a_feature_name.is_empty
		do
			library_name := a_lib_name
			class_name := a_class_name
			feature_name := a_feature_name
		ensure
			lib_set: library_name = a_lib_name
			class_set: class_name = a_class_name
			feature_set: feature_name = a_feature_name
		end

feature -- Access

	library_name: STRING
			-- Owning library

	class_name: STRING
			-- Owning class

	feature_name: STRING
			-- Feature name

	has_require: BOOLEAN
			-- Has precondition?

	has_ensure: BOOLEAN
			-- Has postcondition?

feature -- Modification

	set_has_require (a_value: BOOLEAN)
		do
			has_require := a_value
		end

	set_has_ensure (a_value: BOOLEAN)
		do
			has_ensure := a_value
		end

feature -- Query

	score: INTEGER
			-- Simple score: 0, 50, or 100
		do
			if has_require and has_ensure then
				Result := 100
			elseif has_require or has_ensure then
				Result := 50
			end
		end

end
