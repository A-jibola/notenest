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
    Rails.logger.info "[OAUTH DEBUG] from_omniauth called with provider: #{auth.provider}, uid: #{auth.id}, email: #{auth.info.email}"
    
    # Step 1: Try to find user by provider and uid
    user = User.find_by(provider: auth.provider, uid: auth.id)
    Rails.logger.info "[OAUTH DEBUG] Step 1: Found user by provider/uid: #{user.present? ? "Yes (ID: #{user.id})" : "No"}"
    
    # Step 2: If not found, try to find by email
    if user.nil? && auth.info.email.present?
      user = User.find_by(email: auth.info.email)
      Rails.logger.info "[OAUTH DEBUG] Step 2: Found user by email: #{user.present? ? "Yes (ID: #{user.id})" : "No"}"
      
      if user
        Rails.logger.info "[OAUTH DEBUG] Step 2a: Updating existing user provider/uid if needed"
        user.update(provider: auth.provider, uid: auth.uid) if user.provider.blank?
        
        if user.confirmed? == false
          Rails.logger.info "[OAUTH DEBUG] Step 2b: User not confirmed, attempting to send confirmation email"
          email_start = Time.current
          begin
            user.send_confirmation_instructions
            email_elapsed = Time.current - email_start
            Rails.logger.info "[OAUTH DEBUG] Step 2c: Confirmation email sent successfully in #{email_elapsed}s"
          rescue => e
            email_elapsed = Time.current - email_start
            Rails.logger.error "[OAUTH DEBUG] Step 2c: ERROR sending confirmation email after #{email_elapsed}s: #{e.class} - #{e.message}"
            Rails.logger.error "[OAUTH DEBUG] Step 2c: Backtrace: #{e.backtrace.first(5).join("\n")}"
            raise e  # Re-raise to see the full error
          end
        else
          Rails.logger.info "[OAUTH DEBUG] Step 2b: User already confirmed, skipping email"
        end
      end
    end

    # Step 3: Create new user if not found
    if user.nil?
      Rails.logger.info "[OAUTH DEBUG] Step 3: Creating new user"
      full_name = auth.info.name.to_s.split
      
      create_start = Time.current
      user = User.create(
        provider: auth.provider,
        uid: auth.id,
        email: auth.info.email,
        first_name: auth.info.first_name || full_name.first || "user",
        last_name: auth.info.last_name || full_name.last || "",
        password: Devise.friendly_token[0, 20]
      )
      create_elapsed = Time.current - create_start
      Rails.logger.info "[OAUTH DEBUG] Step 3a: User creation completed in #{create_elapsed}s. Persisted: #{user.persisted?}, Valid: #{user.valid?}, Errors: #{user.errors.full_messages.join(', ')}"

      if user.persisted? && user.confirmed? == false
        Rails.logger.info "[OAUTH DEBUG] Step 3b: New user not confirmed, attempting to send confirmation email"
        email_start = Time.current
        begin
          user.send_confirmation_instructions
          email_elapsed = Time.current - email_start
          Rails.logger.info "[OAUTH DEBUG] Step 3c: Confirmation email sent successfully in #{email_elapsed}s"
        rescue => e
          email_elapsed = Time.current - email_start
          Rails.logger.error "[OAUTH DEBUG] Step 3c: ERROR sending confirmation email after #{email_elapsed}s: #{e.class} - #{e.message}"
          Rails.logger.error "[OAUTH DEBUG] Step 3c: Backtrace: #{e.backtrace.first(10).join("\n")}"
          raise e  # Re-raise to see the full error
        end
      elsif user.persisted?
        Rails.logger.info "[OAUTH DEBUG] Step 3b: New user already confirmed, skipping email"
      end
    end

    Rails.logger.info "[OAUTH DEBUG] from_omniauth returning user ID: #{user.id}, confirmed: #{user.confirmed?}"
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
