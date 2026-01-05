# frozen_string_literal: true

# Configure OmniAuth settings
OmniAuth.config.allowed_request_methods = [:post, :get]

# Configure OAuth2 client timeouts globally
# This monkey patch ensures all OAuth2 requests use increased timeout values
module OAuth2
  class Client
    alias_method :original_initialize, :initialize
    
    def initialize(client_id, client_secret, options = {})
      # Set default timeout options if not already specified
      options = options.dup
      connection_opts = options[:connection_opts] || {}
      request_opts = connection_opts[:request] || {}
      
      request_opts[:open_timeout] ||= 30  # 30 seconds to open connection
      request_opts[:timeout] ||= 60       # 60 seconds total timeout
      
      connection_opts[:request] = request_opts
      options[:connection_opts] = connection_opts
      
      original_initialize(client_id, client_secret, options)
    end
  end
end
