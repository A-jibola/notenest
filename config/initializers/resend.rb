require "resend"

# Set Resend API key globally for the gem's built-in mailer
# This must be set before ActionMailer initializes the delivery method
Resend.api_key = ENV["RESEND_KEY"] if ENV["RESEND_KEY"].present?

