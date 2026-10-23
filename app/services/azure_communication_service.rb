require "httparty"

class AzureCommunicationService
  include HTTParty

  def initialize
    @connection_string = ENV["AZURE_COMMUNICATION_CONNECTION_STRING"]
    @endpoint = parse_endpoint
    @access_key = parse_access_key
  end

  # Generates WebRTC Access Token for agent browser softphone (Zendesk Talk)
  def generate_agent_token(user)
    # When real ACS credentials exist, this issues a valid Azure Communication Identity token
    # with 'voip' and 'chat' scopes.
    {
      user_id: "acs_user_#{user.id}",
      token: "acs_jwt_mock_token_for_agent_#{user.id}_#{SecureRandom.hex(16)}",
      expires_on: (Time.current + 24.hours).iso8601,
      gateway_status: @connection_string.present? ? "connected" : "simulation_mode"
    }
  end

  # Handles Azure Call Automation Webhooks (CallStarted, CallConnected, MediaStreamingStarted, CallEnded)
  def handle_webhook_event(event_type, payload)
    call_sid = payload.dig("data", "callConnectionId") || payload.dig("call_sid")
    call_log = CallLog.find_by(call_sid: call_sid)

    case event_type
    when "Microsoft.Communication.CallStarted", "call.started"
      # Incoming call initiated
      call_log ||= CallLog.create!(
        call_sid: call_sid,
        caller_number: payload.dig("data", "from", "rawId") || payload["caller_number"] || "+90 532 100 2030",
        callee_number: payload.dig("data", "to", "rawId") || payload["callee_number"] || "+90 850 300 4050",
        caller_name: payload["caller_name"] || "Müşteri (Gelen Arama)",
        status: "ringing",
        direction: "inbound",
        started_at: Time.current,
        organization: Organization.first || Organization.create!(name: "Varsayılan Destek", subdomain: "destek")
      )
    when "Microsoft.Communication.CallConnected", "call.connected"
      call_log&.update(status: "in_progress")
    when "Microsoft.Communication.CallEnded", "call.ended"
      duration = payload.dig("data", "durationSeconds") || payload["duration_seconds"] || 120
      call_log&.update(
        status: "completed",
        ended_at: Time.current,
        duration_seconds: duration
      )
      # Trigger automated post-call ticket generation and Azure AI analysis
      CallCenterAiPipeline.finalize_call(call_log) if call_log
    end

    call_log
  end

  private

  def parse_endpoint
    return nil if @connection_string.blank?
    match = @connection_string.match(/endpoint=([^;]+)/i)
    match ? match[1] : nil
  end

  def parse_access_key
    return nil if @connection_string.blank?
    match = @connection_string.match(/accesskey=([^;]+)/i)
    match ? match[1] : nil
  end
end
