module Push
  module Daemon
    module ApnsSupport
      class FeedbackReceiver
        include Push::Daemon::InterruptibleSleep
        include Push::Daemon::DatabaseReconnectable

        FEEDBACK_TUPLE_BYTES = 38

        def initialize(provider)
          @provider = provider
        end

        def start
          @thread = Thread.new do
            loop do
              break if @stop
              check_for_feedback
              interruptible_sleep @provider.configuration[:feedback_poll]
            end
          end
        end

        def stop
          @stop = true
          interrupt_sleep
        end

        def check_for_feedback
          connection = nil
          begin
            connection = ApnsSupport::ConnectionApns.new(@provider)
            connection.connect

            while tuple = connection.read(FEEDBACK_TUPLE_BYTES)
              timestamp, device = parse_tuple(tuple)
              create_feedback(timestamp, device)
            end
          rescue StandardError => e
            Push::Daemon.logger.error(e)
          ensure
            connection.close if connection
          end
        end

        protected

        def parse_tuple(tuple)
          failed_at, _, device = tuple.unpack("N1n1H*")
          [Time.at(failed_at).utc, device]
        end

        def create_feedback(failed_at, device)
          formatted_failed_at = failed_at.strftime("%Y-%m-%d %H:%M:%S UTC")
          Push::Daemon.logger.info("[FeedbackReceiver] Delivery failed at #{formatted_failed_at} for #{device}")
          with_database_reconnect_and_retry(connection.name) do
            Push::FeedbackApns.create!(:app => @provider.configuration[:name], :failed_at => failed_at, :device => device, :follow_up => 'delete')
          end
        end
      end
    end
  end
end