class UserDeactivationJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Find all users without granted access
    users_without_access = User.where(granted_access: false)
    
    users_without_access.find_each do |user|
      days_since_creation = (Time.current - user.created_at) / 1.day
      
      if days_since_creation < 2
        # User is less than 2 days old - send warning if not already sent
        if user.deactivation_warning_sent_at.nil?
          UserDeactivationMailer.warning_email(user).deliver_later
          user.update(deactivation_warning_sent_at: Time.current)
        end
      else
        # User is 2 days or older - cleanup and delete
        user.cleanup_attachments
        UserDeactivationMailer.thank_you_email(user).deliver_now
        user.destroy
      end
    end
  end
end

