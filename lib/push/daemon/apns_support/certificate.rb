module Push
  class CertificateError < StandardError; end

  module Daemon
    module ApnsSupport
      class Certificate
        attr_accessor :certificate

        def initialize(certificate_path)
          @certificate_path = path(certificate_path)
        end

        def path(path)
          if Pathname.new(path).absolute?
            path
          else
            File.join(Rails.root, "config", "push", path)
          end
        end

        def load
          @certificate = read_certificate
        end

        protected

        def read_certificate
          if !File.exists?(@certificate_path)
            raise CertificateError, "#{@certificate_path} does not exist. The certificate location can be configured in config/push/<<environment>>.rb"
          else
            File.read(@certificate_path)
          end
        end
      end
    end
  end
end