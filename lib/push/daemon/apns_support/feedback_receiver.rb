module Push
  module Daemon
    module ApnsSupport
      class FeedbackReceiver
        extend Push::Daemon::InterruptibleSleep
        attr_accessor :provider
        FEEDBACK_TUPLE_BYTES = 38

        def self.start(provider)
          @provider = provider
          @thread = Thread.new do
            loop do
              break if @stop
              check_for_feedback
              interruptible_sleep @provider.configuration[:feedback_poll]
            end
          end
        end

        def self.stop
          @stop = true
          interrupt_sleep
          @thread.join if @thread
        end

        def self.check_for_feedback
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

        def self.parse_tuple(tuple)
          failed_at, _, device = tuple.unpack("N1n1H*")
          [Time.at(failed_at).utc, device]
        end

        def self.create_feedback(failed_at, device)
          formatted_failed_at = failed_at.strftime("%Y-%m-%d %H:%M:%S UTC")
          Push::Daemon.logger.info("[FeedbackReceiver] Delivery failed at #{formatted_failed_at} for #{device}")
          Push::FeedbackApns.create!(:failed_at => failed_at, :device => device, :follow_up => 'delete')
        end
      end
    end
  end
end