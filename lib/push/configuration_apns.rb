module Push
  class ConfigurationApns < Push::Configuration
    store :properties, accessors: [:certificate, :certificate_password, :sandbox, :feedback_poll]
    attr_accessible :app, :enabled, :connections, :certificate, :certificate_password, :sandbox, :feedback_poll
    validates :certificate, :presence => true
    validates :sandbox, :inclusion => { :in => [true, false] }
    validates :feedback_poll, :presence => true

    def name
      :apns
    end
  end
end