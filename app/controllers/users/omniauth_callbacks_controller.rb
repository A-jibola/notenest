class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    handle_oauth_callback("Google")
  end

  def facebook
    handle_oauth_callback("Facebook")
  end

  # Handle OmniAuth failures (e.g., timeouts during token exchange)
  def failure
    error_type = request.env['omniauth.error.type']
    error_message = request.env['omniauth.error']&.message || 'Unknown error'
    error_class = request.env['omniauth.error']&.class&.name || 'Unknown'
    strategy = request.env['omniauth.error.strategy']&.name || 'unknown'
    
    Rails.logger.error "OmniAuth failure - Strategy: #{strategy}, Type: #{error_type}, Class: #{error_class}, Message: #{error_message}"
    
    # Log full error details if available
    if request.env['omniauth.error']
      Rails.logger.error "Full error: #{request.env['omniauth.error'].inspect}"
      Rails.logger.error "Backtrace: #{request.env['omniauth.error'].backtrace&.join("\n")}"
    end
    
    # Provide user-friendly error messages
    user_message = case error_type
    when 'timeout', 'Net::OpenTimeout', 'Net::ReadTimeout', 'Faraday::TimeoutError'
      "Authentication timed out. This may be due to network issues. Please try again."
    when 'invalid_credentials'
      "Invalid credentials. Please try again."
    else
      "Authentication failed. Please try again."
    end
    
    redirect_to new_user_session_path, alert: user_message
  end

  private

  def handle_oauth_callback(provider_name)
    auth_data = request.env["omniauth.auth"]
    
    unless auth_data
      Rails.logger.error "OmniAuth data missing for #{provider_name}"
      redirect_to new_user_session_path, alert: "Authentication failed. Please try again."
      return
    end

    Rails.logger.info "Processing #{provider_name} OAuth callback for user: #{auth_data.info.email}"

    @user = User.from_omniauth(auth_data)
    
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: provider_name) if is_navigational_format?
      Rails.logger.info "Successfully authenticated user via #{provider_name}: #{@user.email}"
    else
      session["devise.#{provider_name.downcase}_data"] = auth_data.except("extra")
      errors = @user.errors.full_messages.join(", ")
      Rails.logger.error "Failed to create user from #{provider_name} OAuth: #{errors}"
      redirect_to new_user_registration_url, alert: "Could not create account. #{errors.presence || 'Please try again.'}"
    end
  rescue OAuth2::Error, Faraday::TimeoutError, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "OAuth timeout/network error for #{provider_name}: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to new_user_session_path, alert: "Authentication timed out. Please try again."
  rescue StandardError => e
    Rails.logger.error "OAuth error for #{provider_name}: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to new_user_session_path, alert: "Authentication failed. Please try again."
  end
end
