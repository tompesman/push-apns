module Push
  class MessageApns < Push::Message
    SELECT_TIMEOUT = 0.2
    ERROR_TUPLE_BYTES = 6
    APN_ERRORS = {
      1 => "Processing error",
      2 => "Missing device token",
      3 => "Missing topic",
      4 => "Missing payload",
      5 => "Missing token size",
      6 => "Missing topic size",
      7 => "Missing payload size",
      8 => "Invalid token",
      255 => "None (unknown error)"
    }
    store :properties, accessors: [:alert, :badge, :sound, :expiry, :attributes_for_device, :content_available]
    attr_accessible :app, :device, :alert, :badge, :sound, :expiry, :attributes_for_device, :content_available if defined?(ActiveModel::MassAssignmentSecurity)

    validates :badge, :numericality => true, :allow_nil => true
    validates :expiry, :numericality => true, :presence => true
    validates :device, :format => { :with => /\A[a-z0-9]{64}\z/ }
    validates_with Push::Apns::BinaryNotificationValidator

    def attributes_for_device=(attrs)
      raise ArgumentError, "attributes_for_device must be a Hash" if !attrs.is_a?(Hash)
      properties[:attributes_for_device] = MultiJson.dump(attrs)
    end

    def attributes_for_device
      MultiJson.load(properties[:attributes_for_device]) if properties[:attributes_for_device]
    end

    def alert=(alert)
      if alert.is_a?(Hash)
        properties[:alert] = MultiJson.dump(alert)
      else
        properties[:alert] = alert
      end
    end

    def alert
      string_or_json = properties[:alert]
      MultiJson.load(string_or_json) rescue string_or_json
    end

    # This method conforms to the enhanced binary format.
    # http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingWIthAPS/CommunicatingWIthAPS.html#//apple_ref/doc/uid/TP40008194-CH101-SW4
    def to_message(options = {})
      id_for_pack = options[:for_validation] ? 0 : id
      [1, id_for_pack, expiry, 0, 32, device, payload_size, payload].pack("cNNccH*na*")
    end

    def use_connection
      Push::Daemon::ApnsSupport::ConnectionApns
    end

    def payload
      MultiJson.dump(as_json)
    end

    def payload_size
      payload.bytesize
    end

    private

    def as_json
      json = ActiveSupport::OrderedHash.new
      json['aps'] = ActiveSupport::OrderedHash.new
      json['aps']['alert'] = alert if alert
      json['aps']['badge'] = badge if badge
      json['aps']['sound'] = sound if sound
      json['aps']['content-available'] = content_available if content_available
      attributes_for_device.each { |k, v| json[k.to_s] = v.to_s } if attributes_for_device
      json
    end

    def check_for_error(connection)
      # check for true, because check_for_error can be nil
      return if connection.provider.configuration[:skip_check_for_error] == true

      if connection.select(SELECT_TIMEOUT)
        error = nil

        if tuple = connection.read(ERROR_TUPLE_BYTES)
          cmd, code, notification_id = tuple.unpack("ccN")

          description = APN_ERRORS[code.to_i] || "Unknown error. Possible push bug?"
          error = Push::DeliveryError.new(code, notification_id, description, "APNS", true, device)
        else
          error = Push::DisconnectionError.new
        end

        begin
          Push::Daemon.logger.error("[#{connection.name}] Error received, reconnecting...")
          connection.reconnect
        ensure
          raise error if error
        end
      end
    end
  end
end