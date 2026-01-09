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
    Rails.logger.info "[USER] from_omniauth STARTED - provider: #{auth.provider}, email: #{auth.info&.email}"
    
    # Step 1: Try to find user by provider and uid
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    Rails.logger.info "[USER] Lookup by provider/uid: #{user.present? ? "Found (ID: #{user.id})" : "Not found"}"
    
    # Step 2: If not found, try to find by email
    if user.nil? && auth.info&.email.present?
      user = User.find_by(email: auth.info.email)
      Rails.logger.info "[USER] Lookup by email: #{user.present? ? "Found (ID: #{user.id})" : "Not found"}"
      
      if user
        user.update(provider: auth.provider, uid: auth.uid) if user.provider.blank?
        
        if user.confirmed? == false
          Rails.logger.info "[USER] Existing user not confirmed, sending confirmation email"
          send_email_with_timing(user, "confirmation")
        end
      end
    end

    # Step 3: Create new user if not found
    if user.nil?
      Rails.logger.info "[USER] Creating new user"
      full_name = auth.info&.name.to_s.split
      
      user_attrs = {
        provider: auth.provider,
        uid: auth.uid,
        email: auth.info&.email,
        first_name: auth.info&.first_name || full_name&.first || "user",
        last_name: auth.info&.last_name || full_name&.last || "",
        password: Devise.friendly_token[0, 20]
      }
      
      create_start = Time.current
      Rails.logger.info "[USER] About to call User.create"
      begin
        user = User.create(user_attrs)
        create_elapsed = Time.current - create_start
        Rails.logger.info "[USER] User.create completed in #{create_elapsed}s - persisted: #{user.persisted?}, valid: #{user.valid?}, id: #{user.id rescue 'N/A'}"
        
        if user.errors.any?
          Rails.logger.error "[USER] User.create errors: #{user.errors.full_messages.join(', ')}"
        end
      rescue => e
        create_elapsed = Time.current - create_start
        Rails.logger.error "[USER] User.create FAILED after #{create_elapsed}s: #{e.class} - #{e.message}"
        Rails.logger.error "[USER] Backtrace: #{e.backtrace.first(10).join("\n")}"
        raise e
      end

      if user.persisted? && user.confirmed? == false
        Rails.logger.info "[USER] New user not confirmed, sending confirmation email"
        send_email_with_timing(user, "confirmation")
      elsif user.persisted?
        Rails.logger.info "[USER] New user already confirmed, skipping email"
      end
    end

    method_elapsed = Time.current - method_start
    Rails.logger.info "[USER] from_omniauth COMPLETED in #{method_elapsed}s - user_id: #{user.id rescue 'N/A'}, confirmed: #{user.confirmed? rescue 'N/A'}"
    user
  end

  def self.send_email_with_timing(user, email_type)
    email_start = Time.current
    Rails.logger.info "[EMAIL] Starting #{email_type} email send for user #{user.id} at #{email_start}"
    Rails.logger.info "[EMAIL] About to call send_confirmation_instructions"
    
    begin
      # Log right before the actual call
      pre_call_time = Time.current
      Rails.logger.info "[EMAIL] Pre-call time: #{pre_call_time}"
      
      user.send_confirmation_instructions
      
      # Log immediately after the call returns
      post_call_time = Time.current
      call_duration = post_call_time - pre_call_time
      Rails.logger.info "[EMAIL] send_confirmation_instructions returned in #{call_duration}s"
      
      email_elapsed = Time.current - email_start
      Rails.logger.info "[EMAIL] #{email_type.capitalize} email send COMPLETED in #{email_elapsed}s"
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      email_elapsed = Time.current - email_start
      Rails.logger.error "[EMAIL] #{email_type.capitalize} email TIMEOUT after #{email_elapsed}s: #{e.class} - #{e.message}"
      Rails.logger.error "[EMAIL] This indicates email delivery timeout (API or network issue)"
      raise e
    rescue => e
      email_elapsed = Time.current - email_start
      Rails.logger.error "[EMAIL] #{email_type.capitalize} email ERROR after #{email_elapsed}s: #{e.class} - #{e.message}"
      Rails.logger.error "[EMAIL] Backtrace: #{e.backtrace.first(10).join("\n")}"
      raise e
    end
  end

  private_class_method :send_email_with_timing

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
