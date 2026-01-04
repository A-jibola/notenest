# frozen_string_literal: true

# Configure OmniAuth with extended timeouts for OAuth providers
# This addresses timeout issues in cloud environments like Render

OmniAuth.config.request_validation_phase = true
OmniAuth.config.allowed_request_methods = [:post, :get]

# Configure OAuth2 client defaults for better timeout handling
# This ensures all OAuth2 requests use extended timeouts
require 'oauth2'

# Monkey patch OAuth2::Client to set default timeouts
# This applies to all OAuth2 requests, including those from omniauth-google-oauth2
module OAuth2TimeoutPatch
  def connection
    @connection ||= begin
      conn = Faraday.new do |builder|
        builder.request :url_encoded
        builder.adapter Faraday.default_adapter
        # Set extended timeouts for cloud environments (30 seconds)
        # Default is usually 10 seconds which can be too short
        builder.options.timeout = 30
        builder.options.open_timeout = 30
        builder.options.read_timeout = 30
      end
      conn
    end
  end
end

OAuth2::Client.prepend(OAuth2TimeoutPatch)

# Note: OAuth providers are configured in config/initializers/devise.rb
# to ensure Devise route helpers (like omniauth_authorize_path) are generated.
# The OAuth2 timeout patch above applies globally to all OAuth2 requests,
# so providers configured in Devise will automatically use extended timeouts.
