class UserDeactivationMailer < ApplicationMailer
  def warning_email(user)
    @user = user
    mail(to: @user.email, subject: "Important: Your Notenest Account Will Be Deactivated Soon")
  end

  def thank_you_email(user)
    @user = user
    mail(to: @user.email, subject: "Thank You for Trying Notenest")
  end
end

