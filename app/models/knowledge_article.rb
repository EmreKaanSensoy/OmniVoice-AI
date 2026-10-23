class KnowledgeArticle < ApplicationRecord
  belongs_to :organization
  belongs_to :author, class_name: "User"

  validates :title, presence: true
  validates :slug, presence: true
  validates :body, presence: true

  before_validation :generate_slug, on: :create

  scope :published, -> { where(status: "published") }
  scope :recent, -> { order(created_at: :desc) }

  private

  def generate_slug
    return if slug.present?
    self.slug = title.parameterize
  end
end
