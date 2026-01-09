class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    callback_start = Time.current
    Rails.logger.info "[OAUTH] Google OAuth2 callback STARTED"
    
    auth = request.env["omniauth.auth"]
    unless auth
      Rails.logger.error "[OAUTH] ERROR: Auth object is nil!"
      return
    end
    
    Rails.logger.info "[OAUTH] Auth provider: #{auth.provider}, email: #{auth.info&.email}"
    
    begin
      user_creation_start = Time.current
      Rails.logger.info "[OAUTH] Calling User.from_omniauth"
      @user = User.from_omniauth(auth)
      user_creation_elapsed = Time.current - user_creation_start
      Rails.logger.info "[OAUTH] User.from_omniauth completed in #{user_creation_elapsed}s"
      
      if @user.persisted?
        Rails.logger.info "[OAUTH] User persisted: ID=#{@user.id}, confirmed=#{@user.confirmed?}"
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      else
        Rails.logger.error "[OAUTH] User not persisted, errors: #{@user.errors.full_messages.join(', ')}"
        redirect_to new_user_registration_url
      end
    rescue => e
      elapsed = Time.current - callback_start
      Rails.logger.error "[OAUTH] ERROR after #{elapsed}s: #{e.class} - #{e.message}"
      Rails.logger.error "[OAUTH] Backtrace: #{e.backtrace.first(10).join("\n")}"
      raise e
    ensure
      total_elapsed = Time.current - callback_start
      Rails.logger.info "[OAUTH] Google OAuth2 callback COMPLETED in #{total_elapsed}s"
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
