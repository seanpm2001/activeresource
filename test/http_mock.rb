require 'active_resource/connection'

module ActiveResource
  class InvalidRequestError < StandardError; end
    
  class HttpMock
    class Responder
      def initialize(responses)
        @responses = responses
      end
      
      for method in [ :post, :put, :get, :delete ]
        module_eval <<-EOE
          def #{method}(path, request_headers = {}, body = nil, status = 200, response_headers = {})
            @responses[Request.new(:#{method}, path, nil, request_headers)] = Response.new(body || {}, status, response_headers)
          end
        EOE
      end
    end

    class << self
      def requests
        @@requests ||= []
      end

      def responses
        @@responses ||= {}
      end

      def respond_to(pairs = {})
        reset!
        pairs.each do |(path, response)|
          responses[path] = response
        end
        yield Responder.new(responses) if block_given?
      end

      def reset!
        requests.clear
        responses.clear
      end
    end

    for method in [ :post, :put ]
      module_eval <<-EOE
        def #{method}(path, body, headers)
          request = ActiveResource::Request.new(:#{method}, path, body, headers)
          self.class.requests << request
          self.class.responses[request] || raise(InvalidRequestError.new("No response recorded for: \#{request}"))
        end
      EOE
    end
    
    for method in [ :get, :delete ]
      module_eval <<-EOE
        def #{method}(path, headers)
          request = ActiveResource::Request.new(:#{method}, path, nil, headers)
          self.class.requests << request
          self.class.responses[request] || raise(InvalidRequestError.new("No response recorded for: \#{request}"))
        end
      EOE
    end
    
    def initialize(site)
      @site = site
    end
  end

  class Request
    attr_accessor :path, :method, :body, :headers
    
    def initialize(method, path, body = nil, headers = {})
      @method, @path, @body, @headers = method, path, body, headers
      @headers.update('Content-Type' => 'application/xml')
    end

    def ==(other_request)
      other_request.hash == hash
    end
    
    def eql?(other_request)
      self == other_request
    end
    
    def to_s
      "<#{method.to_s.upcase}: #{path} [#{headers}] (#{body})>"
    end
    
    def hash
      "#{path}#{method}#{headers}".hash
    end
  end
  
  class Response
    attr_accessor :body, :code, :headers
    
    def initialize(body, code = 200, headers = {})
      @body, @code, @headers = body, code, headers
    end
    
    def success?
      (200..299).include?(code)
    end

    def [](key)
      headers[key]
    end
    
    def []=(key, value)
      headers[key] = value
    end

  end

  class Connection
    private
      silence_warnings do
        def http
          @http ||= HttpMock.new(@site)
        end
      end
  end
end
