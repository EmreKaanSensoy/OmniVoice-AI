class CallTranscript < ApplicationRecord
  belongs_to :call_log

  SPEAKERS = %w[customer agent ai_bot].freeze

  validates :speaker, inclusion: { in: SPEAKERS }
  validates :content, presence: true

  scope :chronological, -> { order(created_at: :asc) }
end
