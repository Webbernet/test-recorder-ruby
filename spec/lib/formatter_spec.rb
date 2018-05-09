describe TestMonitor::Formatter do
  include FormatterSupport

  before do
    stub_const('TestMonitor::Formatter::LOGS_ENABLED', false)
  end

  describe '#dump_summary' do
    it 'prints the standard report' do
      notification = summary_notification(examples(1), examples(1), examples(1))
      send_notification :dump_summary, notification
      expect(formatter_output.string).to match(
        '1 example, 1 failure, 1 pending'
      )
    end

    it 'sets :summary field of output_hash' do
      notification = summary_notification(examples(1), examples(1), examples(1))
      send_notification :dump_summary, notification
      expected = {
        duration: 0,
        errors_outside_of_examples_count: 0,
        example_count: 1,
        failure_count: 1,
        pending_count: 1
      }
      expect(formatter.output_hash[:summary]).to eq expected
    end
  end

  describe '#stop' do
    it 'sets :examples field of output_hash' do
      passed_example = new_example(
        status: :passed, file_path: './spec/passed_spec.rb', line_number: 3
      )
      failed_example = new_example(
        status: :failed, file_path: './spec/failed_spec.rb', line_number: 7
      )
      pending_example = new_example(
        status: :pending, file_path: './spec/pending_spec.rb', line_number: 9
      )

      reporter.example_started passed_example
      reporter.example_started failed_example
      reporter.example_started pending_example

      now = Time.now
      allow(Time).to receive(:now).and_return(now)

      send_notification :stop, stop_notification

      expected = [
        {
          status: 'passed',
          description: 'Example',
          full_description: 'Example',
          file_path: './spec/passed_spec.rb',
          line_number: 3,
          run_time: formatter.output_hash[:examples][0][:run_time],
          timestamp: now.to_i
        },
        {
          status: 'failed',
          description: 'Example',
          full_description: 'Example',
          file_path: './spec/failed_spec.rb',
          line_number: 7,
          run_time: formatter.output_hash[:examples][1][:run_time],
          timestamp: now.to_i,
          exception: { class: 'Exception', message: 'Uh oh', backtrace: nil }
        },
        {
          status: 'pending',
          description: 'Example',
          full_description: 'Example',
          file_path: './spec/pending_spec.rb',
          line_number: 9,
          run_time: formatter.output_hash[:examples][2][:run_time],
          timestamp: now.to_i
        }
      ]
      expect(formatter.output_hash[:examples]).to eq expected
    end
  end

  describe '#close' do
    it 'prints the standard report' do
      stub_request(:post, TestMonitor::Formatter::NOTIFICATION_URL)
        .to_return(status: 200, body: '', headers: {})
      send_notification :close, null_notification
      expect(formatter_output.string).to eq "\n"
    end

    context 'when reports are enabled' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('RUN_TEST_MONITOR').and_return('true')
      end

      it 'sends a JSON report' do
        passed_example = new_example(
          status: :passed, file_path: './spec/passed_spec.rb', line_number: 3
        )
        failed_example = new_example(
          status: :failed, file_path: './spec/failed_spec.rb', line_number: 7
        )
        pending_example = new_example(
          status: :pending, file_path: './spec/pending_spec.rb', line_number: 9
        )

        notification = summary_notification(
          [passed_example], [failed_example], [pending_example]
        )
        send_notification :dump_summary, notification
        reporter.example_started passed_example
        reporter.example_started failed_example
        reporter.example_started pending_example
        send_notification :stop, stop_notification

        now = Time.now
        allow(Time).to receive(:now).and_return(now)

        body = {
          examples: [
            {
              status: 'passed',
              description: 'Example',
              full_description: 'Example',
              file_path: './spec/passed_spec.rb',
              line_number: 3,
              run_time: formatter.output_hash[:examples][0][:run_time],
              timestamp: now.to_i
            },
            {
              status: 'failed',
              description: 'Example',
              full_description: 'Example',
              file_path: './spec/failed_spec.rb',
              line_number: 7,
              run_time: formatter.output_hash[:examples][1][:run_time],
              timestamp: now.to_i,
              exception: {
                class: 'Exception',
                message: 'Uh oh',
                backtrace: nil
              }
            },
            {
              status: 'pending',
              description: 'Example',
              full_description: 'Example',
              file_path: './spec/pending_spec.rb',
              line_number: 9,
              run_time: formatter.output_hash[:examples][2][:run_time],
              timestamp: now.to_i
            }
          ],
          summary: {
            duration: 0,
            example_count: 1,
            failure_count: 1,
            pending_count: 1,
            errors_outside_of_examples_count: 0
          },
          summary_line: '1 example, 1 failure, 1 pending'
        }
        stub_request(:post, TestMonitor::Formatter::NOTIFICATION_URL)
          .with(body: body)
          .to_return(status: 200, body: '', headers: {})

        send_notification :close, null_notification

        expect(WebMock).to have_requested(
          :post, TestMonitor::Formatter::NOTIFICATION_URL
        )
      end

      context 'when request fails' do
        it 'raises an exception' do
          stub_request(:post, TestMonitor::Formatter::NOTIFICATION_URL)
            .with(body: {})
            .to_return(status: 404, body: 'Not found', headers: {})

          expect do
            send_notification :close, null_notification
          end.to raise_error(RestClient::NotFound, '404 Not Found')
        end
      end
    end

    context 'when reports are disabled' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('RUN_TEST_MONITOR').and_return(nil)
      end

      it 'does not send any requsts' do
        send_notification :close, null_notification

        expect(WebMock).not_to have_requested(
          :post, TestMonitor::Formatter::NOTIFICATION_URL
        )
      end
    end
  end

  describe '#seed' do
    context 'use random seed' do
      it 'adds random seed' do
        send_notification :seed, seed_notification(42)
        expect(formatter.output_hash[:seed]).to eq(42)
      end
    end

    context 'do not use random seed' do
      it 'does not add random seed' do
        send_notification :seed, seed_notification(42, false)
        expect(formatter.output_hash[:seed]).to be_nil
      end
    end
  end
end
