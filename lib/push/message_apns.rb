module Push
  class MessageApns < Push::Message
    SELECT_TIMEOUT = 0.2
    ERROR_TUPLE_BYTES = 6
    APNS_PRIORITY_IMMEDIATE = 10
    APNS_PRIORITY_CONSERVE_POWER = 5
    APN_ERRORS = {
      1 =>   "Processing error".freeze,
      2 =>   "Missing device token".freeze,
      3 =>   "Missing topic".freeze,
      4 =>   "Missing payload".freeze,
      5 =>   "Missing token size".freeze,
      6 =>   "Missing topic size".freeze,
      7 =>   "Missing payload size".freeze,
      8 =>   "Invalid token".freeze,
      10 =>  "Shutdown".freeze,
      255 => "None (unknown error)".freeze
    }.freeze
    store :properties, accessors: [:alert, :badge, :sound, :expiry, :attributes_for_device, :content_available, :priority]
    attr_accessible :app, :device, :alert, :badge, :sound, :expiry, :attributes_for_device, :content_available, :priority if defined?(ActiveModel::MassAssignmentSecurity)

    validates :badge, :numericality => true, :allow_nil => true
    validates :expiry, :numericality => true, :presence => true
    validates :priority, :numericality => true, :allow_nil => true
    validates :device, :format => { :with => /\A[a-z0-9]{64}\z/ }
    validates_with Push::Apns::BinaryNotificationValidator

    def attributes_for_device=(attrs)
      raise ArgumentError, "attributes_for_device must be a Hash" unless attrs.is_a?(Hash)
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

    def to_message(options = {})
      frame = ""
      frame << device_token_item
      frame << payload_item
      frame << identifier_item(options)
      frame << expiration_item
      frame << priority_item
      [2, frame.bytesize].pack("cN") + frame
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

    def priority
      if properties[:alert].nil? &&
         properties[:badge].nil? &&
         properties[:sound].nil? &&
         properties[:content_available].present?
        APNS_PRIORITY_CONSERVE_POWER
      else
        properties[:priority].present? ? properties[:priority] : APNS_PRIORITY_IMMEDIATE
      end
    end

    private

    def device_token_item
      [1, 32, device].pack("cnH*")
    end

    def payload_item
      json = payload
      [2, json.bytesize, json].pack("cna*")
    end

    def identifier_item(options)
      frame_id = options[:for_validation] ? 0 : id
      [3, 4, frame_id].pack("cnN")
    end

    def expiration_item
      [4, 4, expiry.to_i].pack("cnN")
    end

    def priority_item
      [5, 1, priority].pack("cnc")
    end

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
