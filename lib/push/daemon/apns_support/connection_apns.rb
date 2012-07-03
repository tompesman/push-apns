module Push
  module Daemon
    module ApnsSupport
      class ConnectionApns
        attr_reader :name, :provider
        attr_accessor :last_write

        def initialize(provider, i=nil)
          @provider = provider
          if i
            # Apns push connection
            @name = "ConnectionApns #{i}"
            @host = "gateway.#{provider.configuration[:sandbox] ? 'sandbox.' : ''}push.apple.com"
            @port = 2195
          else
            @name = "FeedbackReceiver"
            @host = "feedback.#{provider.configuration[:sandbox] ? 'sandbox.' : ''}push.apple.com"
            @port = 2196
          end
          written
        end

        def self.idle_period
          30.minutes
        end

        def connect
          @ssl_context = setup_ssl_context
          @tcp_socket, @ssl_socket = connect_socket
        end

        def close
          begin
            @ssl_socket.close if @ssl_socket
            @tcp_socket.close if @tcp_socket
          rescue IOError
          end
        end

        def read(num_bytes)
          @ssl_socket.read(num_bytes)
        end

        def select(timeout)
          IO.select([@ssl_socket], nil, nil, timeout)
        end

        def write(data)
          reconnect_idle if idle_period_exceeded?

          retry_count = 0

          begin
            write_data(data)
          rescue Errno::EPIPE, Errno::ETIMEDOUT, OpenSSL::SSL::SSLError => e
            retry_count += 1;

            if retry_count == 1
              Push::Daemon.logger.error("[#{@name}] Lost connection to #{@host}:#{@port} (#{e.class.name}), reconnecting...")
            end

            if retry_count <= 3
              reconnect
              sleep 1
              retry
            else
              raise ConnectionError, "#{@name} tried #{retry_count-1} times to reconnect but failed (#{e.class.name})."
            end
          end
        end

        def reconnect
          close
          @tcp_socket, @ssl_socket = connect_socket
        end

        protected

        def reconnect_idle
          Push::Daemon.logger.info("[#{@name}] Idle period exceeded, reconnecting...")
          reconnect
        end

        def idle_period_exceeded?
           Time.now - last_write > self.class.idle_period
        end

        def write_data(data)
          @ssl_socket.write(data)
          @ssl_socket.flush
          written
        end

        def written
          self.last_write = Time.now
        end

        def setup_ssl_context
          ssl_context = OpenSSL::SSL::SSLContext.new
          ssl_context.key = OpenSSL::PKey::RSA.new(provider.certificate.certificate, provider.configuration[:certificate_password])
          ssl_context.cert = OpenSSL::X509::Certificate.new(provider.certificate.certificate)
          ssl_context
        end

        def connect_socket
          tcp_socket = TCPSocket.new(@host, @port)
          tcp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, 1)
          tcp_socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
          ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, @ssl_context)
          ssl_socket.sync = true
          ssl_socket.connect
          Push::Daemon.logger.info("[#{@name}] Connected to #{@host}:#{@port}")
          [tcp_socket, ssl_socket]
        end
      end
    end
  end
end