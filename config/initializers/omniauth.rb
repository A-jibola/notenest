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

# Configure OmniAuth providers with timeout settings
# Note: We configure providers here instead of in devise.rb to have more control
# over timeout settings. Devise will still handle the routes and callbacks.
Rails.application.config.middleware.use OmniAuth::Builder do
  # Facebook OAuth configuration
  if ENV["FACEBOOK_APP_ID"].present? && ENV["FACEBOOK_APP_SECRET"].present?
    provider :facebook, ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_APP_SECRET"],
      client_options: {
        site: 'https://graph.facebook.com/v18.0',
        authorize_url: 'https://www.facebook.com/v18.0/dialog/oauth',
        token_url: 'https://graph.facebook.com/v18.0/oauth/access_token'
      },
      http_options: {
        timeout: 30,
        open_timeout: 30,
        read_timeout: 30
      }
  end

  # Google OAuth2 configuration
  if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
      {
        name: 'google_oauth2',
        scope: 'email,profile',
        prompt: 'select_account',
        access_type: 'offline',
        client_options: {
          site: 'https://accounts.google.com',
          authorize_url: '/o/oauth2/auth',
          token_url: '/o/oauth2/token'
        },
        http_options: {
          timeout: 30,
          open_timeout: 30,
          read_timeout: 30
        }
      }
  end
end
