class User < ApplicationRecord
  has_secure_password

  belongs_to :organization, optional: true
  has_many :requested_tickets, class_name: "Ticket", foreign_key: "requester_id", dependent: :nullify
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: "assignee_id", dependent: :nullify
  has_many :ticket_comments, dependent: :destroy
  has_many :handled_calls, class_name: "CallLog", foreign_key: "agent_id", dependent: :nullify
  has_many :authored_articles, class_name: "KnowledgeArticle", foreign_key: "author_id", dependent: :nullify

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: %w[admin supervisor agent customer] }
  validates :status, inclusion: { in: %w[available on_call busy offline] }

  ROLES = %w[admin supervisor agent customer].freeze
  STATUSES = %w[available on_call busy offline].freeze

  def admin?
    role == "admin"
  end

  def agent?
    %w[admin supervisor agent].include?(role)
  end

  def customer?
    role == "customer"
  end

  def initials
    name.split.map(&:first).join.upcase.slice(0, 2)
  end
end
