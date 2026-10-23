class DashboardController < ApplicationController
  def index
    @org = current_organization
    @tickets = @org.tickets.recent.limit(8)
    
    # Core Support KPIs
    @total_tickets_count = @org.tickets.count
    @unresolved_count = @org.tickets.unresolved.count
    @my_assigned_count = @org.tickets.unresolved.for_agent(current_user.id).count
    @urgent_count = @org.tickets.unresolved.where(priority: %w[high urgent]).count
    @solved_count = @org.tickets.solved.count
    @csat_avg = @org.tickets.where.not(csat_rating: nil).average(:csat_rating)&.round(1) || 4.8

    # Call Center & AI KPIs
    @total_calls_count = @org.call_logs.count
    @active_calls = @org.call_logs.active.recent
    @completed_calls = @org.call_logs.where(status: "completed").recent.limit(5)
    @ai_assisted_count = @org.tickets.where.not(ai_summary: nil).count
    
    # Recent Knowledge Articles
    @recent_articles = @org.knowledge_articles.recent.limit(4)
  end
end
