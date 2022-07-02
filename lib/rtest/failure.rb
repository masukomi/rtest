# lib/failure.rb

module Rtest
  class Failure
    UNPERSISTABLE_ATTRS = Set.new(%i[display_number killable offset persisted]).freeze

    attr_accessor :backtrace,
                  :description,
                  :error_file_path,
                  :error_line_number,
                  :error_method,
                  :expected,
                  :failure_notes,
                  :got,
                  :rspec_arg,
                  :run_time,
                  :spec_file_path,
                  :spec_line_number,
                  :spec_location,
                  :test_name,
                  # meta
                  :display_number,
                  # unpersistable
                  :display_number,
                  :killable,
                  :offset,
                  :persisted

    def initialize
      self.killable = false
      self.offset = 0
    end

    def empty?
      persistable_attr_symbols
        .map { |x| send(x) }
        .reject { |x| x.nil? || x == '' }
        .empty?
    end

    def killable?
      killable
    end

    def persisted?
      persisted
    end

    def rerunable?
      !rspec_arg.blank?
    end

    def has_notes?
      !failure_notes.empty?
    end

    def spec_arg_line_number
      spec_line_number.nil? ? '' : ':' + (spec_line_number + offset).to_s
    end

    def to_hash
      hash = {}
      persistable_attr_symbols.each do |method|
        hash[method] = send(method)
      end
      hash
    end

    def self.from_json(json, display_number = nil)
      new_failure = Failure.new
      json.keys.each do |key|
        new_failure.send("#{key}=".to_sym, json[key])
      end
      new_failure.display_number = display_number if display_number
      new_failure.persisted = true
      new_failure
    end

    private

    def persistable_attr_symbols
      # instance_variables returns something like
      # [:@foo, :@bar, :@baz]
      # and self.send(:@foo) is an error
      instance_variables
        .map { |x| x.to_s.sub('@', '').to_sym }
        .reject { |x| UNPERSISTABLE_ATTRS.include? x }
    end
  end
end
