note
	description: "[
		ORACLE_PROCESS_MONITOR - Process monitoring with timeout and kill capability.

		Runs external processes with timeout monitoring and ability to kill hung processes.
		Uses SIMPLE_ASYNC_PROCESS for true async execution with output capture.

		Architecture:
		- Start a process with run_async
		- Poll is_running to check status
		- Output accumulates in last_output (call refresh_output periodically)
		- Kill if needed with kill
		- Results available after process completes

		Usage:
			monitor: ORACLE_PROCESS_MONITOR
			create monitor.make
			monitor.run_async ("ec.exe ...", "D:\prod\lib", 300)
			from until not monitor.is_running loop
				sleep (1_000_000_000) -- 1 second
				monitor.refresh_output
				if monitor.elapsed_seconds > 300 then
					monitor.kill
				end
			end
			print (monitor.last_output)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	ORACLE_PROCESS_MONITOR

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize monitor.
		do
			create command.make_empty
			create working_dir.make_empty
			create last_output.make_empty
			create last_error.make_empty
			timeout_seconds := 120 -- Default 2 minutes
		end

feature -- Access

	command: STRING_32
			-- Command to execute.

	working_dir: STRING_32
			-- Working directory (empty = current).

	last_output: STRING_32
			-- Output from last/current process.

	last_error: STRING_32
			-- Error message if any.

	last_exit_code: INTEGER
			-- Exit code from process.

	timeout_seconds: INTEGER
			-- Timeout in seconds (default 120).

	is_running: BOOLEAN
			-- Is a process currently running?

	was_successful: BOOLEAN
			-- Did last process complete successfully?

	was_killed: BOOLEAN
			-- Was last process killed due to timeout?

	was_timeout: BOOLEAN
			-- Did process exceed timeout?

	stop_requested: BOOLEAN
			-- Has stop been requested?

	elapsed_seconds: INTEGER
			-- How long has current process been running?

	process_id: NATURAL_32
			-- Process ID (PID) of running process.

	process_is_running: BOOLEAN
			-- Is the underlying async process still running?
		do
			Result := attached async_process as ap and then ap.is_running
		end

feature {NONE} -- Implementation

	async_process: detachable SIMPLE_ASYNC_PROCESS
			-- Underlying async process handler.

feature -- Settings

	set_timeout (a_seconds: INTEGER)
			-- Set timeout in seconds.
		require
			positive: a_seconds > 0
		do
			timeout_seconds := a_seconds
		ensure
			set: timeout_seconds = a_seconds
		end

	set_command (a_command: READABLE_STRING_GENERAL)
			-- Set command to execute.
		require
			not_empty: not a_command.is_empty
		do
			command := a_command.to_string_32
		end

	set_working_dir (a_dir: READABLE_STRING_GENERAL)
			-- Set working directory.
		do
			working_dir := a_dir.to_string_32
		end

feature -- Control

	kill: BOOLEAN
			-- Kill the running process.
			-- Returns True on success.
		require
			running: is_running
		do
			if attached async_process as ap then
				Result := ap.kill
				if Result then
					was_killed := True
					is_running := False
				end
			end
		end

feature -- Execution

	run_async (a_command: READABLE_STRING_GENERAL; a_working_dir: detachable READABLE_STRING_GENERAL; a_timeout: INTEGER)
			-- Start process asynchronously with timeout.
			-- Poll is_running and refresh_output to monitor.
		require
			command_not_empty: not a_command.is_empty
			not_running: not is_running
			positive_timeout: a_timeout > 0
		do
			-- Reset state
			was_successful := False
			was_killed := False
			was_timeout := False
			last_output.wipe_out
			last_error.wipe_out
			last_exit_code := -1

			command := a_command.to_string_32
			if attached a_working_dir as wd then
				working_dir := wd.to_string_32
			else
				working_dir.wipe_out
			end
			timeout_seconds := a_timeout

			-- Start async process
			create async_process.make
			check attached async_process as ap then
				if working_dir.is_empty then
					ap.start (command)
				else
					ap.start_in_directory (command, working_dir)
				end
			end

			if attached async_process as ap and then ap.was_started_successfully then
				is_running := True
				process_id := ap.process_id
			else
				is_running := False
				if attached async_process as ap and then attached ap.last_error as err then
					last_error := err.twin
				else
					last_error := {STRING_32} "Failed to start process"
				end
			end
		end

	refresh_output
			-- Read any available output from process.
			-- Call periodically while process is running.
		do
			if attached async_process as ap then
				if attached ap.read_available_output as chunk then
					last_output.append (chunk)
				end
			end
		end

	finalize
			-- Finalize after process completes.
			-- Call after is_running becomes False.
		require
			not_running: not is_running or not process_is_running
		do
			if attached async_process as ap then
				-- Read any remaining output
				if attached ap.read_available_output as chunk then
					last_output.append (chunk)
				end

				-- Get results
				last_exit_code := ap.exit_code
				elapsed_seconds := ap.elapsed_seconds
				was_successful := last_exit_code = 0

				-- Check timeout
				if elapsed_seconds > timeout_seconds and not was_killed then
					was_timeout := True
					was_successful := False
					last_error := "Process exceeded timeout of " + timeout_seconds.out + " seconds (took " + elapsed_seconds.out + "s)"
				end

				ap.close
				async_process := Void
				is_running := False
			end
		end

	run
			-- Execute synchronously (blocks until complete or timeout).
			-- For backward compatibility.
		require
			command_set: not command.is_empty
			not_running: not is_running
		local
			l_env: EXECUTION_ENVIRONMENT
		do
			run_async (command, working_dir, timeout_seconds)

			-- Poll until complete or timeout
			create l_env
			from
			until
				not is_running or (attached async_process as ap and then not ap.is_running)
			loop
				l_env.sleep (100_000_000) -- 100ms
				refresh_output

				-- Check timeout
				if attached async_process as ap and then ap.elapsed_seconds > timeout_seconds then
					ap.kill.do_nothing
					was_timeout := True
					was_killed := True
				end
			end

			finalize
		ensure
			not_running: not is_running
		end

feature -- Status

	status_report: STRING_32
			-- Human-readable status report.
		do
			create Result.make (200)
			if is_running then
				Result.append ("RUNNING (")
				Result.append (elapsed_seconds.out)
				Result.append ("s / ")
				Result.append (timeout_seconds.out)
				Result.append ("s timeout)")
			elseif was_timeout then
				Result.append ("TIMEOUT after ")
				Result.append (elapsed_seconds.out)
				Result.append ("s (limit: ")
				Result.append (timeout_seconds.out)
				Result.append ("s)")
			elseif was_killed then
				Result.append ("KILLED")
			elseif was_successful then
				Result.append ("SUCCESS (")
				Result.append (elapsed_seconds.out)
				Result.append ("s, exit code ")
				Result.append (last_exit_code.out)
				Result.append (")")
			else
				Result.append ("FAILED (")
				Result.append (elapsed_seconds.out)
				Result.append ("s, exit code ")
				Result.append (last_exit_code.out)
				Result.append (")")
				if not last_error.is_empty then
					Result.append (": ")
					Result.append (last_error)
				end
			end
		end

end
