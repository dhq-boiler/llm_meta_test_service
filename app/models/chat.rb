class Chat < ApplicationRecord
  belongs_to :user, optional: true
  has_many :messages, dependent: :destroy

  validates :llm_uuid, presence: true
  validates :model, presence: true
end
