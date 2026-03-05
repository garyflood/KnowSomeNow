class Device < ApplicationRecord
  belongs_to :user
  has_one :instruction, dependent: :destroy
end
