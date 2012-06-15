module Push
  module Daemon
    class Apns
      attr_accessor :configuration, :certificate

      def initialize(options)
        self.configuration = options

        self.certificate = ApnsSupport::Certificate.new(configuration[:certificate])
        certificate.load

        start_feedback
      end

      def pushconnections
        self.configuration[:connections]
      end

      def totalconnections
        # + feedback
        pushconnections + 1
      end

      def connectiontype
        ApnsSupport::ConnectionApns
      end

      def start_feedback
        ApnsSupport::FeedbackReceiver.start(self)
      end

      def stop_feedback
        ApnsSupport::FeedbackReceiver.stop
      end

      def stop
        stop_feedback
      end
    end
  end
end