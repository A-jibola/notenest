# frozen_string_literal: true

# Configure OmniAuth and Faraday timeouts for OAuth providers
# This ensures proper timeout configuration for omniauth-google-oauth2
# which uses the oauth2 gem (which uses Faraday for HTTP requests)

# Note: request_validation_phase is handled by omniauth-rails_csrf_protection gem
# No need to set it manually

# Configure OAuth2 client defaults by patching the client initialization
# This ensures timeout settings are properly applied to all OAuth2 requests
if defined?(OAuth2)
  OAuth2::Client.class_eval do
    alias_method :original_initialize, :initialize
    
    def initialize(client_id, client_secret, options = {}, &block)
      # Deep merge connection_opts to ensure timeouts are set
      default_opts = {
        connection_opts: {
          request: {
            timeout: 180,
            open_timeout: 60,
            read_timeout: 120
          },
          ssl: {
            verify: true
          }
        }
      }
      
      # Deep merge the options
      options = deep_merge(default_opts, options)
      
      original_initialize(client_id, client_secret, options, &block)
    end
    
    private
    
    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  end
end

# Also configure Faraday adapter defaults as a fallback
require 'faraday' if defined?(Faraday)

Faraday::Connection.class_eval do
  alias_method :original_initialize, :initialize
  
  def initialize(url = nil, options = {})
    # Set default timeouts if not already specified
    options[:request] ||= {}
    options[:request][:timeout] ||= 180 unless options[:request].key?(:timeout)
    options[:request][:open_timeout] ||= 60 unless options[:request].key?(:open_timeout)
    options[:request][:read_timeout] ||= 120 unless options[:request].key?(:read_timeout)
    
    original_initialize(url, options)
  end
end if defined?(Faraday)

# Log configuration for debugging
Rails.logger.info "OmniAuth configured with timeouts: open=60s, read=120s, total=180s" if defined?(Rails.logger)
