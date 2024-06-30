
require_relative "killer"
require_relative "failure_printer"

module Rtest
  # functions for persisting data
  module Persisters
    include Common
    DEFAULT_OPTIONS={renumber: false}
    def update_record_and_display(new_run_data, options=DEFAULT_OPTIONS)
      options = merge_default_options(options)
      persistable_data = update_record(new_run_data, options)
      # vvv from Rtest::Common
      FailurePrinter.display_failures(persistable_data.failures, options)
      puts "⚠️ Failures have been renumbered" if options[:renumber]
      persistable_data
    end

    def update_record_and_display_new(new_run_data, options=DEFAULT_OPTIONS)
      options = merge_default_options(options)
      persistable_data = update_record(new_run_data, options)
      # vvv from Rtest::Common
      FailurePrinter.display_failures(persistable_data.new_failures, options)
      puts "⚠️ Failures have been renumbered" if options[:renumber]
      persistable_data
    end

    def update_record(new_run_data, options=DEFAULT_OPTIONS)
      options = merge_default_options(options)
      persistable_data = Killer.clean_run_data(new_run_data)
      persistable_data.renumber if options[:renumber]
      if persistable_data.has_failures?
        File.write(PAST_RUN_FILENAME, new_run_data.to_json)
      elsif File.exist? PAST_RUN_FILENAME
        File.unlink(PAST_RUN_FILENAME)
      end
      # NOTE: currently we're storing no metadata about
      # the run so "failures" are the only thing we're
      # persisting. If there are no failures let's not
      # waste time reloading this on the next run.
      persistable_data
    end

    protected
    # merges the DEFAULT_OPTIONS with the options passed in
    # This is to guarantee that :renumber has been set,
    # as well as anything else that comes along.
    def merge_default_options(options)
      return DEFAULT_OPTIONS.merge(options || {})
    end
  end
end
