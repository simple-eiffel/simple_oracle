note
	description: "[
		ORACLE_WATCHER_WORKER - SCOOP worker that runs file watcher loop.
		
		Runs on a separate SCOOP processor to watch for file changes
		without blocking the main processor.
		
		Events are logged to its own oracle database connection.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	ORACLE_WATCHER_WORKER

create
	make

feature {NONE} -- Initialization

	make
			-- Create worker with default settings.
		do
			watch_path := Default_watch_path.twin
			stop_requested := False
		end

feature -- Access

	watch_path: STRING
			-- Path being watched.

	stop_requested: BOOLEAN
			-- Has stop been requested?

feature -- Commands

	run
			-- Start the watch loop.
			-- Creates its own oracle connection (each SCOOP processor needs own DB).
		local
			l_watcher: SIMPLE_WATCHER
			l_event: detachable SIMPLE_WATCH_EVENT
			l_oracle: SIMPLE_ORACLE
		do
			-- Create oracle connection for this processor
			create l_oracle.make
			
			-- Watch_file_name (0x0001) | Watch_last_write (0x0010) = 0x0011
			create l_watcher.make (watch_path, True, 0x0011)
			
			if l_watcher.is_valid then
				l_watcher.start
				if l_watcher.last_start_succeeded then
					l_oracle.log_event ("daemon", Void, "Watcher started on path: " + watch_path)
					
					from
					until
						stop_requested
					loop
						-- Wait for events with 500ms timeout
						l_event := l_watcher.wait (500)
						if attached l_event as ev then
							process_event (ev, l_oracle)
						end
					end
					
					l_oracle.log_event ("daemon", Void, "Watcher stopped")
				end
				l_watcher.close
			end
			l_oracle.close
		end

	request_stop
			-- Request the watcher to stop.
		do
			stop_requested := True
		ensure
			stopped: stop_requested
		end

feature {NONE} -- Event Processing

	process_event (a_event: SIMPLE_WATCH_EVENT; a_oracle: SIMPLE_ORACLE)
			-- Process a file system event.
		local
			l_filename: STRING_8
			l_library: detachable STRING_8
			l_details: STRING_8
		do
			l_filename := a_event.filename
			
			-- Only process .e and .ecf files
			if l_filename.ends_with (".e") or l_filename.ends_with (".ecf") then
				-- Extract library name from path
				l_library := extract_library_name (l_filename)
				
				-- Build details string
				create l_details.make (100)
				l_details.append (a_event.event_type_string)
				l_details.append (": ")
				l_details.append (l_filename)
				
				-- Log to oracle
				a_oracle.log_event ("file_change", l_library, l_details)
				
				-- Print to console
				io.put_string ("[")
				io.put_string (a_event.event_type_string)
				io.put_string ("] ")
				if attached l_library as lib then
					io.put_string (lib)
					io.put_string (": ")
				end
				io.put_string (l_filename)
				io.new_line
			end
		end

	extract_library_name (a_path: STRING_8): detachable STRING_8
			-- Extract simple_* library name from path.
			-- Returns Void if not in a simple_* directory.
		local
			l_parts: LIST [STRING_8]
			l_sep: CHARACTER
		do
			-- Path might use / or \
			if a_path.has ('\') then
				l_sep := '\'
			else
				l_sep := '/'
			end
			l_parts := a_path.split (l_sep)
			across l_parts as part loop
				if part.starts_with ("simple_") then
					Result := part.twin
				end
			end
		end

feature {NONE} -- Constants

	Default_watch_path: STRING = "D:\prod"
			-- Default path to watch.

end
