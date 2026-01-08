class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    callback_start = Time.current
    Rails.logger.info "[OAUTH DEBUG] ========== Google OAuth2 callback STARTED at #{callback_start} =========="
    
    # Log full auth object structure
    auth = request.env["omniauth.auth"]
    if auth
      Rails.logger.info "[OAUTH DEBUG] Auth object present: true"
      Rails.logger.info "[OAUTH DEBUG] Auth provider: #{auth.provider}"
      Rails.logger.info "[OAUTH DEBUG] Auth uid: #{auth.uid.inspect}"
      Rails.logger.info "[OAUTH DEBUG] Auth id: #{auth.id.inspect}"
      Rails.logger.info "[OAUTH DEBUG] Auth info present: #{auth.info.present?}"
      if auth.info
        Rails.logger.info "[OAUTH DEBUG] Auth info email: #{auth.info.email.inspect}"
        Rails.logger.info "[OAUTH DEBUG] Auth info name: #{auth.info.name.inspect}"
        Rails.logger.info "[OAUTH DEBUG] Auth info first_name: #{auth.info.first_name.inspect}"
        Rails.logger.info "[OAUTH DEBUG] Auth info last_name: #{auth.info.last_name.inspect}"
      end
      Rails.logger.info "[OAUTH DEBUG] Auth credentials present: #{auth.credentials.present?}"
      if auth.credentials
        Rails.logger.info "[OAUTH DEBUG] Auth credentials token: #{auth.credentials.token.present? ? 'present' : 'missing'}"
        Rails.logger.info "[OAUTH DEBUG] Auth credentials expires: #{auth.credentials.expires.inspect}"
      end
      Rails.logger.info "[OAUTH DEBUG] Full auth object keys: #{auth.to_hash.keys.inspect}"
    else
      Rails.logger.error "[OAUTH DEBUG] ERROR: Auth object is nil!"
    end
    
    start_time = Time.current
    Rails.logger.info "[OAUTH DEBUG] About to call User.from_omniauth at #{start_time}"
    
    begin
      @user = User.from_omniauth(auth)
      
      elapsed = Time.current - start_time
      Rails.logger.info "[OAUTH DEBUG] User.from_omniauth completed in #{elapsed}s"
      Rails.logger.info "[OAUTH DEBUG] User persisted: #{@user.persisted?}"
      Rails.logger.info "[OAUTH DEBUG] User ID: #{@user.id rescue 'N/A'}"
      Rails.logger.info "[OAUTH DEBUG] User confirmed: #{@user.confirmed? rescue 'N/A'}"
      Rails.logger.info "[OAUTH DEBUG] User valid: #{@user.valid? rescue 'N/A'}"
      Rails.logger.info "[OAUTH DEBUG] User errors: #{@user.errors.full_messages.join(', ') rescue 'N/A'}"
      
      if @user.persisted?
        Rails.logger.info "[OAUTH DEBUG] Signing in user and redirecting"
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
      else
        Rails.logger.error "[OAUTH DEBUG] User not persisted, redirecting to registration"
        redirect_to new_user_registration_url
      end
    rescue => e
      elapsed = Time.current - start_time
      Rails.logger.error "[OAUTH DEBUG] ERROR in google_oauth2 after #{elapsed}s: #{e.class} - #{e.message}"
      Rails.logger.error "[OAUTH DEBUG] Backtrace: #{e.backtrace.first(15).join("\n")}"
      raise e
    ensure
      total_elapsed = Time.current - callback_start
      Rails.logger.info "[OAUTH DEBUG] ========== Google OAuth2 callback COMPLETED in #{total_elapsed}s =========="
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
