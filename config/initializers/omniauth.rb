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
    
    # Log when creating Faraday connections (especially for OAuth)
    if url && url.to_s.include?('googleapis.com')
      Rails.logger.info "[OAUTH DEBUG] Creating Faraday connection to #{url} with timeouts: open=#{options[:request][:open_timeout]}s, read=#{options[:request][:read_timeout]}s, total=#{options[:request][:timeout]}s" if defined?(Rails.logger)
    end
    
    original_initialize(url, options)
  end
end if defined?(Faraday)

# Add logging to OAuth2::Client to track when it makes requests
if defined?(OAuth2)
  OAuth2::Client.class_eval do
    alias_method :original_get_token, :get_token
    
    def get_token(params, access_token_opts = {}, access_token_class = OAuth2::AccessToken)
      Rails.logger.info "[OAUTH DEBUG] OAuth2::Client.get_token called at #{Time.current}" if defined?(Rails.logger)
      Rails.logger.info "[OAUTH DEBUG] Making token request to: #{token_url}" if defined?(Rails.logger)
      start_time = Time.current
      
      begin
        token = original_get_token(params, access_token_opts, access_token_class)
        elapsed = Time.current - start_time
        Rails.logger.info "[OAUTH DEBUG] OAuth2::Client.get_token completed in #{elapsed}s" if defined?(Rails.logger)
        token
      rescue => e
        elapsed = Time.current - start_time
        Rails.logger.error "[OAUTH DEBUG] OAuth2::Client.get_token ERROR after #{elapsed}s: #{e.class} - #{e.message}" if defined?(Rails.logger)
        raise e
      end
    end
  end
end

# Log configuration for debugging
Rails.logger.info "OmniAuth configured with timeouts: open=60s, read=120s, total=180s" if defined?(Rails.logger)
