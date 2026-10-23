class Ticket < ApplicationRecord
  belongs_to :organization
  belongs_to :requester, class_name: "User"
  belongs_to :assignee, class_name: "User", optional: true
  has_many :ticket_comments, dependent: :destroy
  has_many :call_logs, dependent: :nullify

  STATUSES = %w[new open pending on_hold solved closed].freeze
  PRIORITIES = %w[low normal high urgent].freeze
  TICKET_TYPES = %w[question incident problem task].freeze
  CHANNELS = %w[web email call_center chat api mobile].freeze

  validates :subject, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :ticket_type, inclusion: { in: TICKET_TYPES }
  validates :channel, inclusion: { in: CHANNELS }

  before_validation :assign_ticket_number, on: :create

  scope :unresolved, -> { where.not(status: %w[solved closed]) }
  scope :solved, -> { where(status: "solved") }
  scope :closed, -> { where(status: "closed") }
  scope :for_agent, ->(user_id) { where(assignee_id: user_id) }
  scope :unassigned, -> { where(assignee_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def open?
    %w[new open pending on_hold].include?(status)
  end

  def solved?
    status == "solved"
  end

  def closed?
    status == "closed"
  end

  def formatted_number
    "##{ticket_number}"
  end

  def status_color
    case status
    when "new" then "#eab308"       # Yellow/Gold
    when "open" then "#ef4444"      # Red
    when "pending" then "#3b82f6"   # Blue
    when "on_hold" then "#6b7280"   # Gray
    when "solved" then "#10b981"    # Emerald
    when "closed" then "#475569"    # Slate
    else "#94a3b8"
    end
  end

  def priority_color
    case priority
    when "urgent" then "#dc2626"
    when "high" then "#f97316"
    when "normal" then "#2563eb"
    when "low" then "#64748b"
    else "#94a3b8"
    end
  end

  private

  def assign_ticket_number
    return if ticket_number.present?
    last_number = organization.tickets.maximum(:ticket_number) || 1000
    self.ticket_number = last_number + 1
  end
end
