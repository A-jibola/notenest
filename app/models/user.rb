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
    binding.break
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
end
