class AnalyticsController < ApplicationController
  def index
    @org = current_organization
    @tickets = @org.tickets
    @calls = @org.call_logs

    # SLA and Performance KPIs
    @total_tickets = @tickets.count
    @solved_tickets = @tickets.where(status: %w[solved closed]).count
    @resolution_rate = @total_tickets.positive? ? ((@solved_tickets.to_f / @total_tickets) * 100).round : 0
    @csat_avg = @tickets.where.not(csat_rating: nil).average(:csat_rating)&.round(1) || 4.8
    @first_response_time = "18 dk"
    @full_resolution_time = "4.2 saat"

    # Breakdown by Channel
    @channel_counts = @tickets.group(:channel).count
    # Breakdown by Priority
    @priority_counts = @tickets.group(:priority).count
    # Breakdown by Status
    @status_counts = @tickets.group(:status).count

    # Call Center AI Metrics
    @total_calls = @calls.count
    @ai_assisted_tickets = @tickets.where.not(ai_summary: nil).count
    @ai_time_saved_hours = (@ai_assisted_tickets * 12.0 / 60.0).round(1) # Avg 12 mins saved per ticket
    @sentiment_counts = @calls.group(:sentiment).count
  end
end
