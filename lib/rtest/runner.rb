# lib/rtest/runner.rb

require_relative "common"
require_relative "persisters"
require_relative "run_log"

module Rtest
  class Runner
    include Persisters

    def self.run_and_display_this(spec, update_file, retries = 0)
        runner = Runner.new()
        run_log = runner.run_this(spec, update_file, retries)
        runner.update_record_and_display(run_log)
    end

    def self.run_this(spec, update_file, retries = 0)
        Runner.new().run_this(spec, update_file, retries)
    end

    def self.fspec_command(spec)
        "bundle exec rspec #{spec} --require #{path_to_formatter()} --format RtestFormatter 2>&1"
    end

    def self.rspec_command(spec)
        "bundle exec rspec #{spec}"
    end

    def run_this(spec, update_file, retries = 0)
        # in a successful run there's nothing in STDERR (2)
        # it's all STDOUT (1)
        run_line = Runner.fspec_command(spec)
        # STDERR.puts("XXX running: #{run_line}")
        # Redirecting STDERR to STDOUT because rspec is...
        # They've made "interesting" choices about what goes where
        output_buffer = interactive_run_handler(run_line, StringIO.new(""))

        # Getting the exit code from PTY.spawn requires calling
        # Process.wait(pid)
        # but that just waits until it exits which will block,
        # so... just gonna have to do without that unless
        # you, my brilliant reader, know a workaround.

        output = output_buffer.string

        if output.match(/^[A-Z]+[a-z]+\w+Error:/)
        failure_extract = extract_meaningful_failure(output)
        puts "\n⚠️ Problems encountered: \n\t#{failure_extract.join("\n\t")}\n..."
        # for whatever reason rspec sends SOME errors to standard out
        # not standard error
        exit 1
        elsif output.match(/(Run `bundle install`|Bundler::GemNotFound|Bundler could not find compatible versions|bundler: command not found: rspec)/m)
        if output.match(/could not find compatible versions/m)
            puts "\nBundler issue you'll have to address..."
            puts output.split("\n")[0..20].join("\n")+"\n..."
            exit 1
        end
        puts "\nYou need to bundle"
        puts "I'll do that for you. Gimme a minute..."
        if retries == 0
            bundle_output, bundle_standard_error, bundle_status = Open3.capture3( "bundle install")
            if bundle_status.exitstatus == 0
            run_this(spec, update_file, 1)
            else
            puts bundle_standard_error
            puts bundle_output
            puts "\n\n\n"
            puts "Nope. I failed to bundle for you. Please reference any errors listed above"
            exit bundle_status.exitstatus
            end
        else
            exit 2
        end
        elsif output.match(/Could not locate Gemfile or \.bundle\/ directory/m)
        puts "\n⚠️ Could not locate Gemfile or .bundle/ directory"
        exit 3
        end

        new_run_data = process_rspec_output(output)
        update_record(new_run_data) if update_file
        # NOTE: update_record removes non-persistable failures.
        # I was intentionally not returning that version,
        # but am considering switching.
        new_run_data
    end

    def interactive_run_handler(run_line, output_buffer)
        PTY.spawn(run_line) do |reader, writer, pid|
        if process_running?(pid)
            while process_running?(pid)
            wait_response = wait_for_read(reader, pid, buffer_last_line(output_buffer))
            if wait_response != :running # ready or debugger
                read_into_buffer(reader, output_buffer)
                # break unless process_running?(pid)
                if ! process_running?(pid)
                break
                end
                if wait_response == :debugger || reader.expect(/^\(byebug\) /, 0.2) #wait 0.2 sec for a match
                puts "\n" + output_buffer.string.split("\n").reverse[0..10].reverse.join("\n")
                user_input = STDIN.gets.chomp
                writer.puts user_input
                sleep 0.2 # give it a moment to exit if it wants to
                else
                #   # did not see ">" within 2 seconds
                #   puts "foo.fail"
                end
                # break unless process_running?(pid)
            end

            read_into_buffer(reader, output_buffer)
            end
        else
            read_into_buffer(reader, output_buffer)
        end
        end
        output_buffer
    end
    # when the run had issues beyond just test failures
    # try and extract goodness from it.
    def extract_meaningful_failure(output)
        lines = output.split(/\r\n|\n/)

        return_lines = []
        lines.each do |line|
        return_lines << line
        break if /^# .*:in/.match(line)
        end
        return_lines
    end

    # returns a RunLog
    def process_rspec_output(output)
        before_rtest_json = true
        json_lines = []
        output.split(/\r\n|\n/).each do |line|
          if before_rtest_json && line == "BEGIN_RTEST_JSON"
            before_rtest_json = false
            next
          elsif before_rtest_json
            next
          else
            json_lines << line
          end
        end
        if before_rtest_json
          STDERR.puts "\n\n⚠️  No Processable Data Returned from RSpec."
          STDERR.puts "RSpec OUTPUT BELOW:\n"
          STDERR.puts output
          exit 0
        end
        RunLog.from_rspec_json(json_lines.join("\n"))
    end

    def process_running?(pid)
        Process.getpgid(pid)
        true # or boom
    rescue
        false
    end

    def buffer_last_line(buffer)
        last_line = buffer.string.split("\n").last
        last_line
    end

    def definite_debugger_line(line)
        return false unless line
        unescaped_line = unescape(line)
        return false if unescaped_line.strip.length == 0
        # puts "line.inspect: '#{line.inspect}'"
        !! unescaped_line.match(/^\(byebug\) $|^\[\d+\] pry\(.*?\)> $/)
    end
    def potential_debugger_pause(line)
        !! unescape(line).match(/^\s*\d+:\s+/)
    end

    def wait_for_read(reader, pid, last_line, counter = 0)
        # counter is a count of times through this with
        # potential debugger pause lines
        running = process_running?(pid)
        while running && ! reader.ready?
        putc "." unless VERBOSE #ironically
        return :debugger if definite_debugger_line(last_line)
        if last_line && potential_debugger_pause(last_line)
            counter += 1
            return :debugger if counter > 4
        end
        sleep 0.2
        end
        if running
        :running
        else
        :ready
        end
    end

    def read_into_buffer(reader, buffer)
        temp_buffer = StringIO.new("")
        loop do
        break unless reader.ready?
        char = reader.read(1)
        break if char.nil?
        temp_buffer.putc(char)
        end

        temp_string = temp_buffer.string
        if temp_string.length > 0
        buffer << temp_string
        end
    end

    def self.path_to_formatter
        RTEST_DIR + File::SEPARATOR + "rtest_formatter.rb"
    end

    end # END RUNNER

end
