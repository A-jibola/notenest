# frozen_string_literal: true

# Configure OmniAuth settings
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.failure_raise_out_environments = [] # Don't raise exceptions, handle in controller

# Patch Faraday to set default timeouts for all HTTP requests
# This ensures OAuth2 requests have proper timeouts
require 'faraday'
require 'json'

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

# Patch OAuth2::Client to handle successful responses that are incorrectly parsed as errors
# This fixes an issue where Google OAuth returns both access_token and id_token,
# and the oauth2 gem's parse_response_legacy incorrectly treats it as an error
module OAuth2
  class Client
    alias_method :original_get_token, :get_token
    
    def get_token(params, access_token_opts = {}, access_token_class = AccessToken)
      retries_remaining = 2
      
      begin
        original_get_token(params, access_token_opts, access_token_class)
      rescue OAuth2::Error => e
        # Check if the error message contains a valid access_token (indicating a successful response)
        # This happens when parse_response_legacy incorrectly treats a valid response as an error
        error_message = e.message.to_s
        
        # Try to parse the error message as JSON to extract tokens
        begin
          if error_message.strip.start_with?('{')
            parsed_response = JSON.parse(error_message)
            
            # If we have an access_token, this is actually a successful response
            if parsed_response['access_token']
              Rails.logger.warn "OAuth2 gem incorrectly parsed successful response as error. Extracting tokens from error message."
              
              # Create a proper AccessToken from the parsed response
              token_hash = {
                'access_token' => parsed_response['access_token'],
                'token_type' => parsed_response['token_type'] || 'Bearer',
                'expires_in' => parsed_response['expires_in'],
                'refresh_token' => parsed_response['refresh_token'],
                'scope' => parsed_response['scope'],
                'id_token' => parsed_response['id_token']
              }.compact
              
              # Return a new AccessToken instance with the extracted data
              return access_token_class.new(self, token_hash, access_token_opts)
            end
          end
        rescue JSON::ParserError
          # If we can't parse it, it's a real error - re-raise it
        end
        
        # If we get here, it's a real error - re-raise it
        raise
      rescue Net::OpenTimeout, Net::ReadTimeout, Faraday::TimeoutError, Timeout::Error => e
        # Retry logic for timeout errors
        if retries_remaining > 0
          retries_remaining -= 1
          Rails.logger.warn "OAuth2 timeout during token exchange, retrying... (#{retries_remaining} retries left): #{e.class} - #{e.message}"
          sleep(2) # Wait 2 seconds before retry
          retry
        else
          Rails.logger.error "OAuth2 timeout after all retries: #{e.class} - #{e.message}"
          raise
        end
      end
    end
  end
end
