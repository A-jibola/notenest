class ReminderEmailNotificationJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Note.due_reminders.find_each do |note|
      ReminderMailer.note_reminder(note).deliver_later
      note.update(reminder_sent: true)
      Notification.create!(
        user: note.user, notifiable: note,
        title: "This note: #{note.title} has been completed",
        read: false, notification_type: "note", send_at: Time.current
      )
    end

    Step.due_reminders.find_each do |step|
      ReminderMailer.step_reminder(step).deliver_later
      step.update(reminder_sent: true)
      Notification.create!(
        user: step.note.user, notifiable: step,
        title: "This step: #{step.name} has been completed",
        read: false, notification_type: "step", send_at: Time.current
      )
    end
  end
end
