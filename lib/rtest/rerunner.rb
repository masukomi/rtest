# frozen_string_literal: true


require_relative 'run_log'
require_relative 'failure_printer'
require_relative 'runner'
require_relative 'print_helpers'

module Rtest
  # Rerunner manages reruns of past failures
  # because individual failures are rerun
  # indpependently there are problems that
  # need to be addressed
  #
  # 1. rspec is always going to start the numbering at 1
  #    (for every run) so we end up with 1, 1, 1, 1...
  # 2. a failure might become fixed and need to be
  #    removed from the list
  # 3. a single failure might become multiple failures
  #    which then need to be recorded.
  #
  # In order to accomplish 2 we need to create
  # a new "past run"  object that we can populate with
  class Rerunner
    include PrintHelpers
    include Persisters
    include Common

    DEFAULT_OPTIONS={persist: false}

    attr_accessor :run_log

    def initialize(run_log)
      self.run_log = run_log
    end

    # rerun all past failures
    def rerun_all(options=DEFAULT_OPTIONS)
      rerun(run_log.failure_numbers, options)
    end

    # rerun one past failure
    def rerun(numbers, options=DEFAULT_OPTIONS)
      numbers = Array(numbers)
      # iterate over each failure,
      # pass it to be rerun
      # collect the resulting failure(s)
      # and replace the existing one with them
      # or kill it if there were none.
      new_run_log = RunLog.new

      # display counter is -1 because
      # i still haven't refactored
      # away from old 0 based index iteration yet
      # TODO: redo how non-rerun iteration & display to be 1 based
      display_counter = 0
      run_log.failures.each_with_index do |failure, index|
        display_counter += 1
        if numbers.include?(index + 1)

          rerun_log = rerun_failure(failure)
          if rerun_log.has_failures?
            display_counter -= 1 # because we're about to increment it n times
            rerun_log.failures.each do |new_failure|
              display_counter += 1

              new_failure.display_number = display_counter
              new_run_log.failures << new_failure
              FailurePrinter.print(new_failure, new_failure.display_number)
            end
          else
            fixed_failure_message(failure)
          end
        else
          new_run_log.failures << failure
        end
      end

      update_record(new_run_log) if options[:persist]
      new_run_log
    end

    def rerun_last_file(options=DEFAULT_OPTIONS)
      last_file = run_log.last_file
      failure_numbers = run_log.failures_in_file(last_file).map(&:display_number)
      rerun(failure_numbers, options)
    end

    private

    def fixed_failure_message(failure)
      print_wrapped_test_name(SUCCESS_COLOR, 'FIXED', failure.test_name, '✅ ')
    end

    # returns a RunLog
    def rerun_failure(failure)
      # TODO: warn if not rerunable
      Runner.run_this(failure.rspec_arg, false)
    end
  end
end
