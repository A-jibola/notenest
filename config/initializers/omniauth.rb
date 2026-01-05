# frozen_string_literal: true

# Configure OmniAuth settings
OmniAuth.config.allowed_request_methods = [:post, :get]

# Configure OAuth2 client timeouts globally
# Patch OAuth2::Client to ensure timeouts are properly set
module OAuth2
  class Client
    alias_method :original_initialize, :initialize
    
    def initialize(client_id, client_secret, options = {})
      # Force timeout options
      options = options.dup
      connection_opts = options[:connection_opts] || {}
      request_opts = connection_opts[:request] || {}
      
      # Force these values (don't use ||= to ensure they're always set)
      request_opts[:open_timeout] = 60  # 60 seconds to open connection
      request_opts[:timeout] = 90       # 90 seconds total timeout
      
      connection_opts[:request] = request_opts
      options[:connection_opts] = connection_opts
      
      original_initialize(client_id, client_secret, options)
    end
  end
end
