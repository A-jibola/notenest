# frozen_string_literal: true

# Configure OmniAuth settings
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.failure_raise_out_environments = [] # Don't raise exceptions, handle in controller

# Patch Faraday to set default timeouts for all HTTP requests
# This ensures OAuth2 requests have proper timeouts
require 'faraday'

module Faraday
  class Connection
    alias_method :original_initialize, :initialize
    
    def initialize(url = nil, options = {})
      # Set default timeouts if not already specified
      options = options.dup
      request_opts = options[:request] || {}
      
      # Force timeout values for OAuth requests (increased for better reliability)
      request_opts[:open_timeout] ||= 120  # 120 seconds to open connection
      request_opts[:timeout] ||= 180        # 180 seconds total timeout
      request_opts[:read_timeout] ||= 120   # 120 seconds read timeout
      
      options[:request] = request_opts
      
      original_initialize(url, options)
    end
  end
end

# Also patch OAuth2::Client to ensure timeouts are properly set
module OAuth2
  class Client
    alias_method :original_initialize, :initialize
    
    def initialize(client_id, client_secret, options = {})
      # Force timeout options
      options = options.dup
      connection_opts = options[:connection_opts] || {}
      request_opts = connection_opts[:request] || {}
      
      # Force these values (increased for better reliability)
      request_opts[:open_timeout] = 120  # 120 seconds to open connection
      request_opts[:timeout] = 180       # 180 seconds total timeout
      request_opts[:read_timeout] = 120  # 120 seconds read timeout
      
      connection_opts[:request] = request_opts
      options[:connection_opts] = connection_opts
      
      original_initialize(client_id, client_secret, options)
    end
  end
end

# Patch OAuth2::Client to add retry logic for token exchange
module OAuth2
  class Client
    alias_method :original_get_token, :get_token
    
    def get_token(params, access_token_opts = {}, access_token_class = AccessToken)
      # Add retry logic for timeout errors during token exchange
      retries = 2
      begin
        original_get_token(params, access_token_opts, access_token_class)
      rescue Net::OpenTimeout, Net::ReadTimeout, Faraday::TimeoutError, Timeout::Error => e
        if retries > 0
          retries -= 1
          Rails.logger.warn "OAuth2 timeout during token exchange, retrying... (#{retries} retries left): #{e.class} - #{e.message}"
          sleep(2) # Wait 2 seconds before retry
          retry
        else
          Rails.logger.error "OAuth2 timeout after #{2 - retries} retries: #{e.class} - #{e.message}"
          raise
        end
      end
    end
  end
end
