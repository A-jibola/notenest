class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?
  layout :layout_by_resource



  private
  def layout_by_resource
    if devise_controller?
      "auth"
    else
      "application"
    end
  end

  protected

  def configure_permitted_parameters
    # Allow the First Name and Last name for user registeration and Update
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end
end
