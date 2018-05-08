require "rspec"
require "json"

module TestMonitor
  class Formatter < RSpec::Core::Formatters::ProgressFormatter
    RSpec::Core::Formatters.register self, :dump_summary, :stop, :seed, :close

    def initialize(output)
      super
      @output_hash = {}
    end

    def dump_summary(summary)
      super(summary)

      @output_hash[:summary] = {
        duration: summary.duration,
        example_count: summary.example_count,
        failure_count: summary.failure_count,
        pending_count: summary.pending_count,
        errors_outside_of_examples_count: summary.errors_outside_of_examples_count
      }
      @output_hash[:summary_line] = summary.totals_line
    end

    def stop(notification)
      @output_hash[:examples] = notification.examples.map { |example| format_example(example) }
    end

    def seed(notification)
      super(notification)

      return unless notification.seed_used?
      @output_hash[:seed] = notification.seed
    end

    def close(_notification)
      super(_notification)

      pp @output_hash
    end

    private

    def format_example(example)
      {
        status: example.execution_result.status.to_s,
        description: example.description,
        full_description: example.full_description,
        file_path: example.metadata[:file_path],
        line_number: example.metadata[:line_number],
        run_time: example.execution_result.run_time,
        timestamp: Time.now.to_i
      }.tap do |hash|
        e = example.exception
        if e
          hash[:exception] =  {
            class: e.class.name,
            message: e.message,
            backtrace: e.backtrace,
          }
        end
      end
    end
  end
end