module Push
  module Apns
    class BinaryNotificationValidator < ActiveModel::Validator

      def validate(record)
        if record.payload_size > 256
          record.errors[:base] << "APN notification cannot be larger than 256 bytes. Try condensing your alert and device attributes."
        end

        if [5, 10].include?(record.priority) == false
          record.errors[:priority] << "APN priority must be 5 or 10."
        end

        if record.alert.nil? &&
           record.badge.nil? &&
           record.sound.nil? &&
           record.content_available.present? &&
           record.priority == 10
           record.errors[:priority] << "APN priority cannot be 10 for a push that contains only the content_available key."
        end
      end
    end
  end
end
