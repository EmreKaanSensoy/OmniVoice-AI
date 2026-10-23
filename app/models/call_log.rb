class CallLog < ApplicationRecord
  belongs_to :organization
  belongs_to :ticket, optional: true
  belongs_to :agent, class_name: "User", optional: true
  has_many :call_transcripts, dependent: :destroy

  STATUSES = %w[queued ringing in_progress completed missed voicemail].freeze
  DIRECTIONS = %w[inbound outbound].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :direction, inclusion: { in: DIRECTIONS }

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[queued ringing in_progress]) }

  def duration_formatted
    mins = duration_seconds / 60
    secs = duration_seconds % 60
    format("%02d:%02d", mins, secs)
  end

  def sentiment_color
    case sentiment
    when "positive" then "#10b981"
    when "neutral" then "#64748b"
    when "negative" then "#ef4444"
    when "frustrated" then "#dc2626"
    else "#94a3b8"
    end
  end
end
