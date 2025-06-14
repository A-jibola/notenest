class Note < ApplicationRecord
  belongs_to :user
  has_many :steps, -> { order(:order) }, dependent: :destroy
  has_many :note_tags, dependent: :destroy
  has_many :tags, through: :note_tags
  has_many :notifications, as: :notifiable
  attr_accessor :tags_input
  accepts_nested_attributes_for :steps, reject_if: ->(attributes) { attributes[:name].blank? }, allow_destroy: true
  has_rich_text :description

  enum :status, {
    draft: 0,
    active: 1,
    completed: 2
  }

  # Set default value for status to 'draft' if not provided
  after_initialize :set_default_status, if: :new_record?

  before_validation :set_step_order
  validates :title, presence: true
  before_save :purge_removed_attachments_from_description

  # private

  scope :due_reminders, -> { where(reminder_sent: false).where.not(reminder_time: nil).where("reminder_time <=?", Time.current) }

  def set_default_status
    self.status ||= :draft
    self.reminder_sent = false
  end

  def set_step_order
    steps.each_with_index do |step, index|
      step.order = index + 1 if step.order.to_i == 0
    end
  end

  def purge_removed_attachments_from_description
    return unless description.body.present?

    # Collect signed IDs of attachments still in the description
    current_attachment_ids = description.body.attachments.map(&:attachable)
      .select { |a| a.is_a?(ActiveStorage::Blob) }.map(&:id)

    # Get all attached blobs associated with this rich text
    old_attachment_ids = description.embeds.map(&:blob_id)

    # Find ones that are no longer in use
    removed_ids = old_attachment_ids - current_attachment_ids

    # Purge them
    ActiveStorage::Blob.where(id: removed_ids).find_each do |blob|
      Cloudinary::Uploader.destroy(blob.key)
      blob.purge
    end
  end
end
