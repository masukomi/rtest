# frozen_string_literal: true

require_relative "common"
require_relative "persisters"


module Rtest
  class Killer
    include Common
    include Persisters
    # returns a new array of failures
    # without the killable ones.
    def self.cull_failures(failures)
      failures.reject(&:killable)
    end

    def self.clean_run_data(run_data)
      run_data.failures.reject!(&:killable)
      run_data
    end

    # the numbers passed in are the user-facing numbers
    def self.mark_for_death(run_log, numbers)
      Array(numbers).each do |n|
        failure = run_log.get_failure_by_number(n)
        if failure
          failure.killable = true
        else
          warn("#{ERROR_LINE_COLOR}Can't find #{n} for killing.#{COLOR_RESET}")
        end
      end
      run_log
    end

    def self.kill(run_log, numbers)
      mark_for_death(run_log, numbers) # mutates failures in log
      # NOTE: honestly unsure if renumber should be true or false here.
      Killer.new().update_record(run_log, renumber: true)
    end
    def self.kill_and_display(run_log, numbers)
      mark_for_death(run_log, numbers) # mutates failures in log
      # NOTE: honestly unsure if renumber should be true or false here.
      Killer.new().update_record_and_display(run_log, renumber: true)
    end
  end
end
