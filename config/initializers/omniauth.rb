# frozen_string_literal: true

# Configure OmniAuth with extended timeouts for OAuth providers
# This addresses timeout issues in cloud environments like Render

OmniAuth.config.allowed_request_methods = [:post, :get]

# Configure Faraday defaults for extended timeouts
# This applies to all HTTP requests made through Faraday, including OAuth2
require 'faraday'

Faraday.default_connection_options.timeout = 30
Faraday.default_connection_options.open_timeout = 30
Faraday.default_connection_options.read_timeout = 30

# Note: OAuth providers are configured in config/initializers/devise.rb
# with timeout options. The Faraday defaults above provide a fallback
# for any OAuth requests that don't explicitly set timeouts.
