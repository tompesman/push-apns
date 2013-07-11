module Push
  class ConfigurationApns < Push::Configuration
    store :properties, accessors: [:certificate, :certificate_password, :sandbox, :feedback_poll, :skip_check_for_error]
    attr_accessible :app, :enabled, :connections, :certificate, :certificate_password, :sandbox, :feedback_poll if defined?(ActiveModel::MassAssignmentSecurity)
    validates :certificate, :presence => true
    validates :sandbox, :inclusion => { :in => [true, false] }
    validates :feedback_poll, :presence => true
    validates :skip_check_for_error, :inclusion => { :in => [true, false] }, :allow_blank => true

    def name
      :apns
    end
  end
end