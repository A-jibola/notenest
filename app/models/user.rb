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
    method_start = Time.current
    Rails.logger.info "[OAUTH DEBUG] ========== from_omniauth STARTED at #{method_start} =========="
    Rails.logger.info "[OAUTH DEBUG] Auth provider: #{auth.provider.inspect}"
    Rails.logger.info "[OAUTH DEBUG] Auth uid: #{auth.uid.inspect}"
    Rails.logger.info "[OAUTH DEBUG] Auth id: #{auth.id.inspect}"
    Rails.logger.info "[OAUTH DEBUG] Auth info email: #{auth.info&.email.inspect}"
    Rails.logger.info "[OAUTH DEBUG] Auth info name: #{auth.info&.name.inspect}"
    
    # Validate auth data completeness
    if auth.id.blank?
      Rails.logger.error "[OAUTH DEBUG] ERROR: auth.id is blank! This indicates OAuth callback may not have completed."
      Rails.logger.error "[OAUTH DEBUG] Auth object inspect: #{auth.inspect}"
    end
    
    # Step 1: Try to find user by provider and uid
    step1_start = Time.current
    Rails.logger.info "[OAUTH DEBUG] Step 1: Starting user lookup by provider/uid at #{step1_start}"
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    step1_elapsed = Time.current - step1_start
    Rails.logger.info "[OAUTH DEBUG] Step 1: Completed in #{step1_elapsed}s. Found: #{user.present? ? "Yes (ID: #{user.id})" : "No"}"
    
    # Step 2: If not found, try to find by email
    if user.nil? && auth.info&.email.present?
      step2_start = Time.current
      Rails.logger.info "[OAUTH DEBUG] Step 2: Starting user lookup by email at #{step2_start}"
      user = User.find_by(email: auth.info.email)
      step2_elapsed = Time.current - step2_start
      Rails.logger.info "[OAUTH DEBUG] Step 2: Completed in #{step2_elapsed}s. Found: #{user.present? ? "Yes (ID: #{user.id})" : "No"}"
      
      if user
        Rails.logger.info "[OAUTH DEBUG] Step 2a: Updating existing user provider/uid if needed"
        update_start = Time.current
        user.update(provider: auth.provider, uid: auth.uid) if user.provider.blank?
        update_elapsed = Time.current - update_start
        Rails.logger.info "[OAUTH DEBUG] Step 2a: Update completed in #{update_elapsed}s"
        
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
            raise e
          end
        else
          Rails.logger.info "[OAUTH DEBUG] Step 2b: User already confirmed, skipping email"
        end
      end
    end

    # Step 3: Create new user if not found
    if user.nil?
      Rails.logger.info "[OAUTH DEBUG] Step 3: Preparing to create new user"
      full_name = auth.info&.name.to_s.split
      
      user_attrs = {
        provider: auth.provider,
        uid: auth.uid,
        email: auth.info&.email,
        first_name: auth.info&.first_name || full_name&.first || "user",
        last_name: auth.info&.last_name || full_name&.last || "",
        password: Devise.friendly_token[0, 20]
      }
      Rails.logger.info "[OAUTH DEBUG] Step 3: User attributes prepared: #{user_attrs.except(:password).inspect}"
      
      create_start = Time.current
      Rails.logger.info "[OAUTH DEBUG] Step 3: About to call User.create at #{create_start}"
      
      begin
        user = User.create(user_attrs)
      rescue => e
        create_elapsed = Time.current - create_start
        Rails.logger.error "[OAUTH DEBUG] Step 3: ERROR during User.create after #{create_elapsed}s: #{e.class} - #{e.message}"
        Rails.logger.error "[OAUTH DEBUG] Step 3: Backtrace: #{e.backtrace.first(15).join("\n")}"
        raise e
      end
      
      create_elapsed = Time.current - create_start
      Rails.logger.info "[OAUTH DEBUG] Step 3a: User.create returned after #{create_elapsed}s"
      Rails.logger.info "[OAUTH DEBUG] Step 3a: User persisted: #{user.persisted?}"
      Rails.logger.info "[OAUTH DEBUG] Step 3a: User valid: #{user.valid?}"
      Rails.logger.info "[OAUTH DEBUG] Step 3a: User errors: #{user.errors.full_messages.join(', ')}"
      Rails.logger.info "[OAUTH DEBUG] Step 3a: User ID: #{user.id rescue 'N/A'}"
      Rails.logger.info "[OAUTH DEBUG] Step 3a: User confirmed: #{user.confirmed? rescue 'N/A'}"

      if user.persisted? && user.confirmed? == false
        Rails.logger.info "[OAUTH DEBUG] Step 3b: New user not confirmed, attempting to send confirmation email"
        email_start = Time.current
        Rails.logger.info "[OAUTH DEBUG] Step 3b: About to call send_confirmation_instructions at #{email_start}"
        begin
          user.send_confirmation_instructions
          email_elapsed = Time.current - email_start
          Rails.logger.info "[OAUTH DEBUG] Step 3c: Confirmation email sent successfully in #{email_elapsed}s"
        rescue => e
          email_elapsed = Time.current - email_start
          Rails.logger.error "[OAUTH DEBUG] Step 3c: ERROR sending confirmation email after #{email_elapsed}s: #{e.class} - #{e.message}"
          Rails.logger.error "[OAUTH DEBUG] Step 3c: Backtrace: #{e.backtrace.first(10).join("\n")}"
          raise e
        end
      elsif user.persisted?
        Rails.logger.info "[OAUTH DEBUG] Step 3b: New user already confirmed, skipping email"
      end
    end

    method_elapsed = Time.current - method_start
    Rails.logger.info "[OAUTH DEBUG] from_omniauth returning user ID: #{user.id rescue 'N/A'}, confirmed: #{user.confirmed? rescue 'N/A'}"
    Rails.logger.info "[OAUTH DEBUG] ========== from_omniauth COMPLETED in #{method_elapsed}s =========="
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
