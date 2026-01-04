class User < ApplicationRecord
  validates :first_name, presence: true
  validates :last_name, presence: true
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [ :facebook, :google_oauth2 ]

  has_many :notes, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :notifications, dependent: :destroy

  def self.from_omniauth(auth)
    user = User.find_by(provider: auth.provider, uid: auth.id)
    if user.nil? && auth.info.email.present?
      user = User.find_by(email: auth.info.email)
      if user
        user.update(provider: auth.provider, uid: auth.uid) if user.provider.blank?
        if user.confirmed? == false
          user.send_confirmation_instructions
        end
      end
    end

    if user.nil?
      full_name = auth.info.name.to_s.split
      user = User.create(
        provider: auth.provider,
        uid: auth.id,
        email: auth.info.email,
        first_name: auth.info.first_name || full_name.first || "user",
        last_name: auth.info.last_name || full_name.last || "",
        password: Devise.friendly_token[0, 20]
      )

      if user.persisted? && user.confirmed? == false
        user.send_confirmation_instructions
      end
    end

    user
  end

  # Find all ActiveStorage blobs associated with user's notes via ActionText
  def all_attachments
    note_ids = notes.pluck(:id)
    return ActiveStorage::Blob.none if note_ids.empty?
    
    # Find all ActionText rich text records for user's notes
    rich_text_ids = ActionText::RichText.where(record_type: 'Note', record_id: note_ids).pluck(:id)
    return ActiveStorage::Blob.none if rich_text_ids.empty?
    
    # Find ActiveStorage attachments associated with these rich texts
    blob_ids = ActiveStorage::Attachment.where(
      record_type: 'ActionText::RichText',
      record_id: rich_text_ids
    ).pluck(:blob_id)
    
    return ActiveStorage::Blob.none if blob_ids.empty?
    
    # Get associated blobs
    ActiveStorage::Blob.where(id: blob_ids)
  end

  # Cleanup attachments: Delete from Cloudinary first, then purge from ActiveStorage
  def cleanup_attachments
    all_attachments.find_each do |blob|
      begin
        # Delete from Cloudinary
        Cloudinary::Uploader.destroy(blob.key) if blob.key.present?
      rescue => e
        # Log error but continue with ActiveStorage purge to prevent orphaned records
        Rails.logger.error("Failed to delete blob #{blob.id} from Cloudinary: #{e.message}")
      ensure
        # Always purge from ActiveStorage
        blob.purge
      end
    end
  end
end
