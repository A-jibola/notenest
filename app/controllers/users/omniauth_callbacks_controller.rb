class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    Rails.logger.info "[OAUTH DEBUG] Google OAuth2 callback started at #{Time.current}"
    Rails.logger.info "[OAUTH DEBUG] Auth data present: #{request.env['omniauth.auth'].present?}"
    Rails.logger.info "[OAUTH DEBUG] Email from auth: #{request.env['omniauth.auth']&.info&.email}"
    
    start_time = Time.current
    Rails.logger.info "[OAUTH DEBUG] Calling User.from_omniauth at #{start_time}"
    
    @user = User.from_omniauth(request.env["omniauth.auth"])
    
    elapsed = Time.current - start_time
    Rails.logger.info "[OAUTH DEBUG] User.from_omniauth completed in #{elapsed}s. User persisted: #{@user.persisted?}, User ID: #{@user.id}, Confirmed: #{@user.confirmed?}"
    
    if @user.persisted?
      Rails.logger.info "[OAUTH DEBUG] Signing in user and redirecting"
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      Rails.logger.error "[OAUTH DEBUG] User not persisted, redirecting to registration"
      # session["devise.google_oauth2_data"] = request.env["omniauth.auth.email"]
      redirect_to new_user_registration_url
    end
  end

  def facebook
    @user = User.from_omniauth(request.env["omniauth.auth"])
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Facebook") if is_navigational_format?
    else
      redirect_to new_user_registration_url
    end
  end
end
