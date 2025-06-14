class ProfileSettingsController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(user_params)
      redirect_to edit_profile_settings_path, notice: "Theme Updated Successfully"
    else
      render :edit
    end
  end

  private

  def user_params
    params.require(:user).permit(:theme, :font).delete_if { |_k, v| v.blank? }
  end
end
