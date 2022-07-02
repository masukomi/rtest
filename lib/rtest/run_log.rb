# frozen_string_literal: true

require 'json'
require_relative 'rerunner'
require_relative 'failure'

module Rtest
  class RunLog
    attr_accessor :failures

    def self.from_json(json)
      rl = RunLog.new
      failure_objects = []

      json['failures'].each_with_index do |json_f, index|
        failure_objects << Failure.from_json(json_f, (index + 1))
      end
      rl.failures = failure_objects

      rl
    end

    def self.from_rspec_json(json_string)
      rl = RunLog.new
      unless json_string.to_s == '' || /^\s+$/.match(json_string.to_s)
        json = JSON.parse(json_string)
        json.each do |failure_hash|
          rl.failures << Failure.from_json(failure_hash)
        end
      end
      rl
    end

    # It is expected that the file won't exist
    # In that scenario we just create a new RunLog
    # File
    def self.from_file(file_path)
      from_json(JSON.parse(File.read(file_path)))
    rescue StandardError => e
      warn("problem parsing #{filename}: #{e.message}")
      # something usable for new run at least...
      RunLog.new
    end

    def initialize
      self.failures = []
    end

    def has_failures?
      failure_count.positive?
    end

    def failure_count
      failures.size
    end

    def failure_numbers
      failures.map(&:display_number)
    end

    def get_failure_by_number(number)
      failures.each do |f|
        return f if f.display_number == number
      end
      nil
    end

    def renumber
      failures.each_with_index do | f , index|
        f.display_number=index + 1
      end
    end

    # at the moment "failures" are the only thing
    # stored about a run.
    # Over time I expect more metadata will be added
    def to_json(*_args)
      JSON.pretty_generate(
        { 'failures' => failures.map { |f| f.killable? ? nil : f.to_hash }.flatten }
      )
    end

    def rerun_all
      Rerunner.new(self).rerun_all
    end

    def rerun_numbers(numbers)
      Rerunner.new(self).rerun(numbers)
    end

    def last_file
      failures
        .map { |f| f.spec_file_path || f.file }
        .select { |f| f.end_with?('_spec.rb') }
        .last
    end

    def failures_in_file(spec_file)
      failures.select { |f| f.spec_file_path == spec_file }
    end

    def new_failures
      failures.reject(&:persisted?)
    end
  end
end
