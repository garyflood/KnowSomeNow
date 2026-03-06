class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :devices, dependent: :destroy

  # Add this custom validation for password complexity
  validate :password_complexity, if: -> { password.present? }

  private

  def password_complexity
    return if password.blank?

    requirements = {
      "at least 8 characters" => password.length >= 8,
      "at least one uppercase letter" => password.match?(/[A-Z]/),
      "at least one lowercase letter" => password.match?(/[a-z]/),
      "at least one number" => password.match?(/\d/),
      "at least one special character (!@#$%^&*)" => password.match?(/[\W_]/)
    }

    missing_requirements = requirements.select { |_, met| !met }.keys

    return unless missing_requirements.any?

    errors.add(:password, "must include #{missing_requirements.join(', ')}")
  end
end
