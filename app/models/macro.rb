class Macro < ApplicationRecord
  belongs_to :organization

  validates :title, presence: true

  serialize :actions, coder: JSON
end
