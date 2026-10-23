class CallCenterChannel < ApplicationCable::Channel
  def subscribed
    stream_from "call_center_#{params[:organization_id] || 1}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def whisper_assist(data)
    # Agent requests live suggestion or manual prompt to Azure AI
    recent_chunks = CallTranscript.where(call_log_id: data["call_id"]).last(5).map do |c|
      { speaker: c.speaker, content: c.content }
    end

    suggestion = AzureOpenAiService.new.suggest_agent_response(recent_chunks)

    ActionCable.server.broadcast(
      "call_center_#{params[:organization_id] || 1}",
      {
        type: "agent_assist_suggestion",
        call_id: data["call_id"],
        suggestion: suggestion
      }
    )
  end
end
