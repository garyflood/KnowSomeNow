class Device < ApplicationRecord
  belongs_to :user
  has_one :instruction, dependent: :destroy

  validates :name, presence: true
  validate :name_must_be_valid_device, if: :name_changed?

  private

  def name_must_be_valid_device
    # Your RubyLLM validation logic here
    chat = RubyLLM.chat
    validation_prompt = <<~PROMPT
      Could "#{name}" fit the description of "device"?
      Respond with ONLY a single word: either "true" or "false".
      Do not add any explanation or additional text.
    PROMPT

    response = chat.ask(validation_prompt)
    result = response.content.strip.downcase

    errors.add(:name, "is not a valid device") unless result.include?('true')
  rescue StandardError => e
    # Log error but don't block creation
    Rails.logger.error "Device validation failed: #{e.message}"
    errors.add(:name, "could not be validated at this time. Please try again.")
  end
end
