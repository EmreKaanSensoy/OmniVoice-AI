class TicketCommentsController < ApplicationController
  def create
    @ticket = current_organization.tickets.find(params[:ticket_id])
    @comment = @ticket.ticket_comments.new(comment_params)
    @comment.user = current_user

    if @comment.save
      # If agent changes ticket status via reply bar (e.g., Submit as Solved)
      if params[:new_status].present? && Ticket::STATUSES.include?(params[:new_status])
        @ticket.update(status: params[:new_status])
      end

      redirect_to ticket_path(@ticket), notice: @comment.is_internal? ? "İç not eklendi." : "Müşteri yanıtı iletildi."
    else
      redirect_to ticket_path(@ticket), alert: "Yanıt boş bırakılamaz."
    end
  end

  private

  def comment_params
    params.require(:ticket_comment).permit(:body, :is_internal, :comment_type)
  end
end
