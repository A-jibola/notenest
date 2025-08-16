class Step < ApplicationRecord
  belongs_to :note
  has_rich_text :details
  has_many :notifications, as: :notifiable


  enum :status, {
    pending: 0,
    in_progress: 1,
    completed: 2
  }

  validates :name, presence: true

  after_initialize :set_default_status, if: :new_record?

  private
  scope :due_reminders, -> { where(reminder_at: false).where.not(reminder_at: nil).where("reminder_at <=?", Time.current) }

  def set_default_status
    self.status ||= :pending
    self.reminder_sent = false
  end
end
