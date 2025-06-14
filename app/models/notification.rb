class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  enum :notification_type, { note: "note", step: "step" }

  after_create_commit -> { broadcast_append_to "notifications_user_#{user.id}",
   target: "notifications", partial: "notifications/notification", locals: { notification: self }}
end
