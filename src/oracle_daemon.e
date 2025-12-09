note
	description: "[
		ORACLE_DAEMON - File system watcher for Simple Eiffel ecosystem.
		
		Monitors D:\prod\simple_* directories for:
		- .e file changes (Eiffel source)
		- .ecf file changes (project config)
		
		Auto-logs events to the oracle database for ecosystem monitoring.
		
		SCOOP Architecture:
		- Main processor handles CLI and user interaction
		- Watcher processor runs the file watcher loop
		- Each processor has its own oracle DB connection
		
		Usage:
			oracle-daemon start   -- Start watching
			oracle-daemon stop    -- Stop watching (via PID file)
			oracle-daemon status  -- Show daemon status
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	ORACLE_DAEMON

create
	make

feature {NONE} -- Initialization

	make
			-- Run the daemon based on command line arguments.
		local
			l_args: ARGUMENTS_32
			l_cmd: STRING_8
		do
			create l_args
			create oracle.make
			
			if l_args.argument_count < 1 then
				print_usage
			else
				l_cmd := l_args.argument (1).to_string_8.as_lower
				if l_cmd.same_string ("start") then
					start_watching
				elseif l_cmd.same_string ("stop") then
					stop_watching
				elseif l_cmd.same_string ("status") then
					show_status
				elseif l_cmd.same_string ("once") then
					watch_once
				else
					print_usage
				end
			end
			
			oracle.close
		end

feature -- Commands

	start_watching
			-- Start the file watcher daemon with SCOOP.
		local
			l_worker: separate ORACLE_WATCHER_WORKER
		do
			io.put_string ("Starting Oracle Daemon (SCOOP)...%N")
			io.put_string ("Watching: " + Watch_path + "%N")
			io.put_string ("Press Enter to stop%N%N")
			
			write_pid_file
			oracle.log_event ("daemon", Void, "Daemon started, watching " + Watch_path)
			
			-- Create worker on separate processor
			create l_worker.make
			
			-- Launch watcher (asynchronous call via wrapper)
			launch_worker (l_worker)
			
			-- Wait for user input to stop
			io.read_line
			
			-- Signal stop via wrapper (separate argument rule)
			stop_worker (l_worker)
			
			-- Clean up
			remove_pid_file
			oracle.log_event ("daemon", Void, "Daemon stopped")
			io.put_string ("Daemon stopped.%N")
		end

	stop_watching
			-- Stop the daemon by removing the PID file.
		do
			if pid_file_exists then
				remove_pid_file
				io.put_string ("Stop signal sent to daemon.%N")
			else
				io.put_string ("No daemon is running (no PID file found).%N")
			end
		end

	show_status
			-- Show daemon status.
		do
			io.put_string ("Oracle Daemon Status%N")
			io.put_string ("====================%N")
			if pid_file_exists then
				io.put_string ("Status: RUNNING%N")
				io.put_string ("PID file: " + Pid_file_path + "%N")
			else
				io.put_string ("Status: STOPPED%N")
			end
			io.put_string ("Watch path: " + Watch_path + "%N")
			io.put_string ("%NRecent daemon events:%N")
			show_recent_daemon_events
		end

	watch_once
			-- Poll once for testing (non-SCOOP version).
		local
			l_watcher: SIMPLE_WATCHER
			l_event: detachable SIMPLE_WATCH_EVENT
		do
			io.put_string ("Single poll test...%N")
			-- Watch_file_name (0x0001) | Watch_last_write (0x0010) = 0x0011
			create l_watcher.make (Watch_path, True, 0x0011)
			
			if l_watcher.is_valid then
				l_watcher.start
				if l_watcher.last_start_succeeded then
					io.put_string ("Watcher started. Waiting 5 seconds for events...%N")
					l_event := l_watcher.wait (5000)
					if attached l_event as ev then
						io.put_string ("Event: " + ev.event_type_string + " - " + ev.filename + "%N")
						process_event (ev)
					else
						io.put_string ("No events detected.%N")
					end
				end
				l_watcher.close
			else
				io.put_string ("Failed to create watcher%N")
			end
		end

feature {NONE} -- SCOOP Launchers (separate argument rule compliance)

	launch_worker (a_worker: separate ORACLE_WATCHER_WORKER)
			-- Launch the watcher on its separate processor.
			-- Asynchronous: returns immediately, worker runs in background.
		do
			a_worker.run
		end

	stop_worker (a_worker: separate ORACLE_WATCHER_WORKER)
			-- Request the worker to stop.
		do
			a_worker.request_stop
		end

feature {NONE} -- Event Processing (for watch_once)

	process_event (a_event: SIMPLE_WATCH_EVENT)
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
				oracle.log_event ("file_change", l_library, l_details)
				
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

feature {NONE} -- PID File Management

	pid_file_exists: BOOLEAN
			-- Does the PID file exist?
		local
			l_file: RAW_FILE
		do
			create l_file.make_with_name (Pid_file_path)
			Result := l_file.exists
		end

	write_pid_file
			-- Write PID file to indicate daemon is running.
		local
			l_file: PLAIN_TEXT_FILE
		do
			create l_file.make_create_read_write (Pid_file_path)
			l_file.put_string ("running")
			l_file.close
		end

	remove_pid_file
			-- Remove PID file.
		local
			l_file: RAW_FILE
		do
			create l_file.make_with_name (Pid_file_path)
			if l_file.exists then
				l_file.delete
			end
		end

feature {NONE} -- Output

	print_usage
			-- Print usage information.
		do
			io.put_string ("Oracle Daemon - Ecosystem File Watcher%N")
			io.put_string ("======================================%N")
			io.put_string ("Usage: oracle-daemon <command>%N%N")
			io.put_string ("Commands:%N")
			io.put_string ("  start   - Start watching for file changes%N")
			io.put_string ("  stop    - Stop the daemon%N")
			io.put_string ("  status  - Show daemon status%N")
			io.put_string ("  once    - Single poll (for testing)%N")
		end

	show_recent_daemon_events
			-- Show recent daemon-related events.
		do
			across oracle.recent_events (24) as ev loop
				if ev.event_type.same_string ("daemon") or ev.event_type.same_string ("file_change") then
					io.put_string ("  [")
					io.put_string (ev.timestamp.to_string_8)
					io.put_string ("] ")
					io.put_string (ev.event_type.to_string_8)
					io.put_string (": ")
					io.put_string (ev.details.to_string_8)
					io.new_line
				end
			end
		end

feature {NONE} -- Implementation

	oracle: SIMPLE_ORACLE
			-- Oracle instance for main processor logging.

feature {NONE} -- Constants

	Watch_path: STRING = "D:\prod"
			-- Root path to watch.

	Pid_file_path: STRING = "D:\prod\simple_oracle\oracle-daemon.pid"
			-- PID file location.

end
