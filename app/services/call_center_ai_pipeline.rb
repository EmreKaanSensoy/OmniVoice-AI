class CallCenterAiPipeline
  class << self
    # Adds a streaming speech-to-text chunk into call transcript
    def record_chunk(call_log, speaker:, content:, sentiment: "neutral", offset_ms: 0)
      chunk = call_log.call_transcripts.create!(
        speaker: speaker,
        content: content,
        sentiment: sentiment,
        offset_ms: offset_ms
      )

      # Append to cumulative full transcript
      current_full = call_log.transcript_full.to_s
      new_line = "#{speaker.upcase}: #{content}\n"
      call_log.update_column(:transcript_full, current_full + new_line)

      # Broadcast live chunk to agent dashboard via ActionCable
      ActionCable.server.broadcast(
        "call_center_#{call_log.organization_id}",
        {
          type: "transcript_chunk",
          call_id: call_log.id,
          speaker: speaker,
          content: content,
          sentiment: sentiment,
          offset_ms: offset_ms
        }
      )

      chunk
    end

    # Post-call automated processing:
    # 1. Azure OpenAI analysis (summary, intent, sentiment, tags)
    # 2. Creates or updates associated Ticket
    # 3. Creates internal timeline comment with full audio transcript & action items
    def finalize_call(call_log)
      return if call_log.blank?

      ai_service = AzureOpenAiService.new(organization: call_log.organization)
      analysis = ai_service.analyze_call_transcript(
        call_log.transcript_full.presence || "Görüşme içeriği kaydedilmedi.",
        { name: call_log.caller_name, phone: call_log.caller_number }
      )

      call_log.update(
        ai_summary: analysis["summary"],
        ai_action_items: analysis["action_items"],
        detected_intent: analysis["intent"],
        sentiment: analysis["sentiment"]
      )

      # Auto-create or link Ticket
      organization = call_log.organization
      requester = find_or_create_requester(call_log, organization)

      ticket = call_log.ticket || organization.tickets.create!(
        subject: "[Çağrı Merkezi - #{analysis['intent'] || 'Destek'}] #{call_log.caller_name}",
        description: analysis["summary"] || "Azure AI Çağrı Özeti",
        channel: "call_center",
        status: analysis["suggested_ticket_status"] || "open",
        priority: analysis["suggested_priority"] || "normal",
        requester: requester,
        assignee: call_log.agent,
        tags: Array(analysis["tags"]).join(", "),
        ai_summary: analysis["summary"],
        ai_sentiment: analysis["sentiment"],
        ai_suggested_action: analysis["action_items"]
      )

      call_log.update(ticket: ticket)

      # Add internal system comment containing post-call intelligence
      ticket.ticket_comments.create!(
        user: call_log.agent || requester,
        is_internal: true,
        comment_type: "call_log",
        body: <<~BODY
          🎙️ **Microsoft Call Center AI - Çağrı Tamamlandı**
          - **Arayan:** #{call_log.caller_name} (#{call_log.caller_number})
          - **Süre:** #{call_log.duration_formatted}
          - **Duygu Durumu:** #{analysis['sentiment']&.upcase}
          - **Arama Amacı:** #{analysis['intent']}

          📋 **Yapay Zeka Görüşme Özeti:**
          #{analysis['summary']}

          ⚡ **Önerilen Aksiyon Maddeleri:**
          #{analysis['action_items']}
        BODY
      )

      # Broadcast completion to frontend
      ActionCable.server.broadcast(
        "call_center_#{call_log.organization_id}",
        {
          type: "call_completed",
          call_id: call_log.id,
          ticket_id: ticket.id,
          ticket_number: ticket.ticket_number,
          summary: analysis["summary"]
        }
      )

      ticket
    end

    private

    def find_or_create_requester(call_log, organization)
      customer_email = "customer_#{call_log.caller_number.to_s.gsub(/[^0-9]/, '')}@example.com"
      customer = organization.users.find_by(email: customer_email)
      customer ||= organization.users.create!(
        name: call_log.caller_name.presence || "Müşteri #{call_log.caller_number}",
        email: customer_email,
        phone: call_log.caller_number,
        role: "customer",
        password: SecureRandom.hex(10)
      )
      customer.update(phone: call_log.caller_number) if customer.phone.blank? && call_log.caller_number.present?
      customer
    end
  end
end
