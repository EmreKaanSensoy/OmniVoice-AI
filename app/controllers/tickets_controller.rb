class TicketsController < ApplicationController
  before_action :set_ticket, only: [:show, :edit, :update, :destroy, :apply_macro, :update_status, :trigger_callback]
  skip_before_action :verify_authenticity_token, only: [:update_status, :trigger_callback]

  def edit
  end

  def destroy
    @ticket.destroy
    redirect_to tickets_path, notice: "Bilet silindi."
  end

  def index
    @view = params[:view] || "unresolved"
    scope = current_organization.tickets

    @tickets = case @view
               when "my_tickets"
                 scope.unresolved.for_agent(current_user.id)
               when "unassigned"
                 scope.unresolved.unassigned
               when "urgent"
                 scope.unresolved.where(priority: %w[high urgent])
               when "solved"
                 scope.solved
               when "all"
                 scope.recent
               else # "unresolved"
                 scope.unresolved
               end

    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      @tickets = @tickets.where("LOWER(subject) LIKE ? OR CAST(ticket_number AS TEXT) LIKE ?", query, query)
    end

    if params[:channel].present?
      @tickets = @tickets.where(channel: params[:channel])
    end

    @tickets = @tickets.recent

    # Counts for Zendesk-like left view sidebar
    @counts = {
      unresolved: scope.unresolved.count,
      my_tickets: scope.unresolved.for_agent(current_user.id).count,
      unassigned: scope.unresolved.unassigned.count,
      urgent: scope.unresolved.where(priority: %w[high urgent]).count,
      solved: scope.solved.count
    }
  end

  def show
    @comments = @ticket.ticket_comments.chronological
    @new_comment = TicketComment.new(ticket: @ticket)
    @agents = current_organization.users.where(role: %w[admin agent supervisor])
    @macros = current_organization.macros
    @related_calls = @ticket.call_logs.recent
    @suggested_articles = current_organization.knowledge_articles.limit(3)
  end

  def new
    @ticket = current_organization.tickets.new(priority: "normal", status: "new")
    @agents = current_organization.users.where(role: %w[admin agent supervisor])
    @customers = current_organization.users.where(role: "customer")
  end

  def create
    @ticket = current_organization.tickets.new(ticket_params)
    @ticket.requester ||= current_user

    if @ticket.save
      redirect_to ticket_path(@ticket), notice: "Bilet ##{@ticket.ticket_number} başarıyla oluşturuldu."
    else
      @agents = current_organization.users.where(role: %w[admin agent supervisor])
      @customers = current_organization.users.where(role: "customer")
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @ticket.update(ticket_params)
      respond_to do |format|
        format.html { redirect_to ticket_path(@ticket), notice: "Bilet güncellendi." }
        format.json { render json: { status: "success", ticket: @ticket } }
      end
    else
      respond_to do |format|
        format.html { redirect_to ticket_path(@ticket), alert: "Güncelleme başarısız." }
        format.json { render json: { status: "error", errors: @ticket.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update_status
    if Ticket::STATUSES.include?(params[:status])
      @ticket.update(status: params[:status])
      @ticket.ticket_comments.create!(
        user: current_user,
        is_internal: true,
        comment_type: "system_event",
        body: "Durum '#{params[:status].upcase}' olarak güncellendi."
      )

      # If marked as solved, automatically trigger outbound AI callback to the customer
      if params[:status] == "solved" && @ticket.requester&.phone.present?
        OutboundCallService.trigger_resolution_call(@ticket, current_user)
        redirect_to ticket_path(@ticket), notice: "✅ Bilet çözüldü ve müşteriye (#{@ticket.requester.phone}) otomatik AI sesli geri araması yapıldı!"
      else
        redirect_to ticket_path(@ticket), notice: "Bilet durumu '#{params[:status]}' yapıldı."
      end
    else
      redirect_to ticket_path(@ticket), alert: "Geçersiz durum."
    end
  end

  def trigger_callback
    call_log = OutboundCallService.trigger_resolution_call(@ticket, current_user)
    if call_log
      redirect_to ticket_path(@ticket), notice: "📞 Müşteri (#{@ticket.requester&.phone}) otomatik AI sesli aramasıyla bilgilendirildi."
    else
      redirect_to ticket_path(@ticket), alert: "Müşterinin kayıtlı bir telefon numarası bulunamadı."
    end
  end

  def apply_macro
    macro = current_organization.macros.find(params[:macro_id])
    actions = macro.actions || {}

    # Add comment if present in macro
    if actions["add_comment"].present?
      @ticket.ticket_comments.create!(
        user: current_user,
        body: actions["add_comment"],
        is_internal: false,
        comment_type: "message"
      )
    end

    if actions["add_internal_note"].present?
      @ticket.ticket_comments.create!(
        user: current_user,
        body: actions["add_internal_note"],
        is_internal: true,
        comment_type: "message"
      )
    end

    updates = {}
    updates[:status] = actions["set_status"] if actions["set_status"].present?
    updates[:priority] = actions["set_priority"] if actions["set_priority"].present?
    
    if actions["add_tags"].present?
      existing_tags = @ticket.tags.to_s.split(",").map(&:strip)
      new_tags = (existing_tags + Array(actions["add_tags"])).uniq.join(", ")
      updates[:tags] = new_tags
    end

    @ticket.update(updates) if updates.any?

    redirect_to ticket_path(@ticket), notice: "'#{macro.title}' makrosu uygulandı."
  end

  private

  def set_ticket
    @ticket = current_organization.tickets.find(params[:id])
  end

  def ticket_params
    params.require(:ticket).permit(:subject, :description, :status, :priority, :ticket_type, :channel, :assignee_id, :requester_id, :tags)
  end
end
