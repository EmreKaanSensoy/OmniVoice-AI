class TicketComment < ApplicationRecord
  belongs_to :ticket
  belongs_to :user

  COMMENT_TYPES = %w[message call_log system_event ai_agent_assist].freeze

  validates :body, presence: true
  validates :comment_type, inclusion: { in: COMMENT_TYPES }

  serialize :metadata, coder: JSON

  scope :public_replies, -> { where(is_internal: false) }
  scope :internal_notes, -> { where(is_internal: true) }
  scope :chronological, -> { order(created_at: :asc) }
end
