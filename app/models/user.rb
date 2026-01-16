class User < ApplicationRecord
  devise :omniauthable, omniauth_providers: %i[google_oauth2]

  has_many :chats, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :google_id, presence: true, uniqueness: true
  validates :id_token, presence: true

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize(
      google_id: auth.uid
    )

    token = auth.extra&.id_token
    if token.blank?
      user.errors.add(:id_token, "is missing from provider response")
      return user
    end

    user.id_token = token
    user.save
    user
  end

  # Return Google ID token (OpenID Connect)
  # Validate expiration timestamp when using the token
  def jwt_token
    id_token if id_token.present? && token_valid?
  end

  private

  # Check whether the ID token is valid
  def token_valid?
    return false if id_token.blank?

    begin
      # Attempt to decode JWT (no signature verification; only checks expiration)
      decoded_token = JWT.decode(id_token, nil, false)
      payload = decoded_token.first
      exp = payload["exp"] if payload

      # Valid if current time is before expiration
      exp && Time.now.to_i < exp
    rescue JWT::DecodeError, JWT::ExpiredSignature
      false
    end
  end
end
