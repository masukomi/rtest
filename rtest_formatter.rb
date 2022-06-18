# RSpec::Core::Example notes
#  methods relevant to this work
#  - description
#    - "test_convert_error"
#  - example_group
#  - execution_result -> ExecutionResult object
#    #<RSpec::Core::Example::ExecutionResult:0x0000000106586310
#      @started_at=2022-06-17 11:27:17.447464 -0400,
#      @status=:failed,
#      @finished_at=2022-06-17 11:27:17.453267 -0400,
#      @run_time=0.005803,
#      @exception=#<RSpec::Expectations::ExpectationNotMetError:
#        expected: == "INTENTIONAL FAILURE" got:    "ick">>
#  - file_path
#  - full_description
#    - "Multipart::Post::CompositeReadIO test_convert_error"
#  - id
#  - inspect (just for debugging)
#  - inspect_output (description + guaranteed location included)
#  - location - exact source location of this example:
#               ex ./path/to/spec.rb:17
#  - location_rerun_argument
#    - returns the location-based argument that can be passed to the rspec command to rerun
#      this example
#    - ?? typically the same as the location
#  - pending?
#  - skipped?

require 'json'


class Failure
  # The regex to match ANSI codes
  # from https://github.com/piotrmurach/strings-ansi
  ANSI_MATCHER = %r{
    (?>\033(
      \[[\[?>!]?\d*(;\d+)*[ ]?[a-zA-Z~@$^\]_\{\\] # graphics
      |
      \#?\d # cursor modes
      |
      [)(%+\-*/. ](\d|[a-zA-Z@=%]|) # character sets
      |
      O[p-xA-Z] # special keys
      |
      [a-zA-Z=><~\}|] # cursor movement
      |
      \]8;[^;]*;.*?(\033\\|\07) # hyperlink
    ))
  }x.freeze

  attr_accessor :backtrace,
                :description,
                :error_file_path,
                :error_line_number,
                :error_method,
                :expected,
                :failure_notes,
                :got,
                :spec_line_number,
                :rspec_arg,
                :run_time,
                :spec_file_path,
                :spec_location,
                :test_name

  # example: RSpec::Core::Example
  # failure: FailedExampleNotification
  def initialize(notification)
    self.failure_notes=[]

    example = notification.example

    extract_attrs_from_example(example)
    extract_attrs_from_notification(notification)
  end

  # removes gems, rspec, and bundle lines from your backtrace
  # This, of course, presumes you're not actually editing one
  # of those.
  def filtered_backtrace
    eliptified_lines = backtrace.map{ |line| filterable_line?(line) ? "…" : line }
    last_line = nil
    eliptified_lines.reject{ |line|
      if line == "…" && last_line == "…"
        true
      else
        last_line = line
        false
      end
    }

    # backtrace.reject{ |line| line.include?("/lib/ruby/") \
    #                   || line.include?("/bin/rspec") \
    #                   || line.include?("/bin/bundle") \
    #                   || line.include?("/spec_helper.rb")
    # }
  end
  def filterable_line?(line)
    line.include?("/lib/ruby/") \
      || line.include?("/bin/rspec") \
      || line.include?("/bin/bundle") \
      || line.include?("/spec_helper.rb")
  end

  def to_json
    hash = {}
    self.instance_variables.map{ |x| x.to_s.sub("@", "").to_sym }.each do | method |
      hash[method] = self.send(method)
    end
    hash[:backtrace] = filtered_backtrace

    JSON.pretty_generate(hash)
  end

  def inspect
    self.to_json
  end

  private

  def unescape(text)
    text.gsub(ANSI_MATCHER, '')
  end

  def extract_attrs_from_example(example)
    self.test_name = example.description
    self.rspec_arg = example.location_rerun_argument
    self.spec_file_path = example.file_path
    self.run_time = example.execution_result.run_time
    self.spec_line_number = extract_line_number(example.location)
    self.spec_location = example.location
  end

  def extract_attrs_from_notification(notification)
    self.backtrace = notification.formatted_backtrace || []
    extract_message_elements(notification)

    extract_failure_location(filtered_backtrace)

  end


  def extract_message_elements(notification)
    lines = notification
              .message_lines
              .map{ |line| unescape(line.sub(/^\s+/, '')) }
              .reject{ |line| line.empty? }
    # sholud be [failure/error, expected, got, <optional comparison note>]
    # but i don't want to assume
    lines.each do | line|
      prefix  = line.sub(/:.*/, '')
      content = line.sub(/^.*?:/, '')

      if prefix == "Failure/Error"
        self.description = content
      elsif line.start_with? "expected"
        self.expected = content
      elsif line.start_with? "got"
        self.got = content
      else
        # it's a non-blank line with content that isn't one of the above...
        #
        self.failure_notes << line
      end
    end
  end

  def extract_line_number(path_with_line_number)
    m = /.*:(\d+)$/.match(path_with_line_number)
    m.nil? ? nil : m[1].to_i
  end

  def extract_failure_location(lines)
    lines.each do | line |
      m = /(.*(?<!_spec).rb):(\d+):in.*?`(.*)'/.match(line)
      if m
        self.error_file_path   = m[1]
        self.error_line_number = m[2]
        self.error_method      = m[3]
      end
    end
  end

end

class RtestFormatter
  # rspec 3.11 docs for making them
  # https://relishapp.com/rspec/rspec-core/v/3-11/docs/formatters/custom-formatters

  # register it with rspec, and tell it what notifications you want
  # https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FFormatters%2Eregister
  #  .register(formatter_class, *notifications) ⇒ void
  #
  #   formatter_class (Class) — formatter class to register
  #   notifications (Array<Symbol>) — one or more notifications to
  #     be registered to the specified formatter

  RSpec::Core::Formatters.register self,
                                   :example_failed,
                                   :close
  def initialize(output)
    @output = output
    @failures = []
  end

  # notification RSpec::Core::Notifications::ExampleNotification
  # https://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/ExampleNotification
  def example_started(notification)
    # notification.example is an RSpec::Core::Example
    # https://www.rubydoc.info/gems/rspec-core/RSpec/Core/Example

    # @output << "example: " << notification.example.description
  end

  # called if the example passes
  # notification: ExampleNotification
  # http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/ExampleNotification
  def example_passed(notification)
  end

  # called if the example fails
  # notification: FailedExampleNotification
  # http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/FailedExampleNotification
  def example_failed(notification)
    # FailedExampleNotification
    # colorizer param's unspecified default is ::RSpec::Core::Formatters::ConsoleCodes
    #
    #  - colorized_formatted_backtrace(colorizer) -> Array<String>
    #  - colorized_message_lines(colorizer) - Array<String>
    #  - description -> String
    #    "Multipart::Post::CompositeReadIO test_empty_parts"
    #  - example -> RSpec::Core::Example
    #    #<RSpec::Core::Example "test_empty_parts">
    #  - exception -> Exception
    #    #<RSpec::Expectations::ExpectationNotMetError:
    #      expected: == "INTENTIONAL FAILURE"
    #      got:    "ick">
    #    OR
    #    MultipleExpectationsNotMetError...
    #  - formatted_backtrace -> Array<String>
    #  - fully_formatted(failure_number, colorizer) -> String
    #  - fully_formatted_lines(failure_number, colorizer) -> Array<String>
    #  - message_lines -> Array<String>
    # #  ["Failure/Error: expect(io.read(3)).to be == \"INTENTIONAL FAILURE\"", "", "  expected: == \"INTENTIONAL FAILURE\"", "       got:    \"ick\""]
    #     FORMATTED:
    #     Failure/Error: expect(io.read(3)).to be == "INTENTIONAL FAILURE"
    #
    #       expected: == "INTENTIONAL FAILURE"
    #            got:    "ick"
    #
    ####
    # Notes:
    # notification.exception.message
    #   "expected: == \"INTENTIONAL FAILURE\"\n     got:    \"ick\""
    f = Failure.new(notification)
    @failures << f
  end

  # called if the example is marked as pending
  # notification: ExampleNotification
  # http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/ExampleNotification
  def example_pending(notification)
  end

  # the following methods are all called in the order presented
  # notification: ExamplesNotification (PLURAL)
  # http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/ExamplesNotification
  def stop(notification)

  end

  # notification: NullNotification http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/NullNotification
  def start_dump(notification)
  end


  # notification: ExamplesNotification (PLURAL)
  # http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/ExamplesNotification
  def dump_failures(notification)
  end

  # notification: SummaryNotification
  # http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/SummaryNotification
  def dump_summary(notification)
  end

  # notification: NullNotification http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/NullNotification
  def close(_)
    @output << "BEGIN_RTEST_JSON"
    @output << "\n[\n#{@failures.map{ |f|f.to_json }.join(",\n")}\n]"
  end
end
