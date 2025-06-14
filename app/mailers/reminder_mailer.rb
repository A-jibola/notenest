class ReminderMailer < ApplicationMailer
  default from: "okesolajibola@gmail.com"
  # let's get this to a better email next time

  def note_reminder(note)
    @note = note
    @user = note.user
    mail(to: @user.email, subject: "Reminder: #{@note.title}")
  end
  def step_reminder(step)
    @step = step
    @user = step.note.user
    mail(to: @user.email, subject: "Reminder: #{@step.name}")
  end
end
