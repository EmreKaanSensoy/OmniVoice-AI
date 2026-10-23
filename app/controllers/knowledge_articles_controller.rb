class KnowledgeArticlesController < ApplicationController
  def index
    @articles = current_organization.knowledge_articles.published
    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      @articles = @articles.where("LOWER(title) LIKE ? OR LOWER(body) LIKE ?", query, query)
    end
    if params[:category].present?
      @articles = @articles.where(category: params[:category])
    end
    @categories = current_organization.knowledge_articles.distinct.pluck(:category)
  end

  def show
    @article = current_organization.knowledge_articles.find(params[:id])
    @article.increment!(:views_count)
    @related_articles = current_organization.knowledge_articles.where(category: @article.category).where.not(id: @article.id).limit(3)
  end
end
