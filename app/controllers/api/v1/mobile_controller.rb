class Api::V1::MobileController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  before_action :set_cors_headers

  # 1. Sesle Bilet Açma (Mobile Voice Ticket Creator)
  def voice_ticket
    transcript = params[:transcript].presence || params[:voice_text].presence || "Mobil uygulamadan iletilen sesli destek talebi."
    caller_name = params[:customer_name].presence || "Emre Kaan (Mobil)"
    caller_phone = params[:customer_phone].presence || "+90 554 720 0828"

    org = current_organization || Organization.first

    # 1. Müşteri kullanıcısını bul veya oluştur
    customer = User.find_by(phone: caller_phone) || 
               User.find_by(email: "musteri@acme.com") ||
               User.create!(
                 organization: org,
                 name: caller_name,
                 email: "mobil_#{SecureRandom.hex(4)}@acme.com",
                 phone: caller_phone,
                 role: "customer",
                 password: "password123"
               )

    # 2. Azure OpenAI GPT-4o ile Konuşmayı Analiz Et
    ai_service = AzureOpenAiService.new
    ai_analysis = ai_service.analyze_call_transcript(transcript, { name: caller_name, phone: caller_phone })

    subject = ai_analysis["intent"].presence || "Mobil Sesli Destek Talebi"
    priority = %w[low normal high urgent].include?(ai_analysis["suggested_priority"]) ? ai_analysis["suggested_priority"] : "normal"
    sentiment = ai_analysis["sentiment"] || "neutral"
    summary = ai_analysis["summary"] || transcript
    suggested_action = ai_analysis["action_items"]

    # 3. Bileti Oluştur (Admin Paneline Canlı Düşer)
    ticket = org.tickets.create!(
      subject: subject,
      description: transcript,
      status: "new",
      priority: priority,
      ticket_type: "incident",
      channel: "mobile",
      requester: customer,
      ai_sentiment: sentiment,
      ai_summary: summary,
      ai_suggested_action: suggested_action
    )

    # 4. Çağrı Kaydını Sisteme İşle
    call_log = org.call_logs.create!(
      call_sid: "mobile-voice-#{SecureRandom.hex(6)}",
      caller_number: caller_phone,
      callee_number: org.phone_number_formatted,
      caller_name: caller_name,
      ticket: ticket,
      direction: "inbound",
      status: "completed",
      started_at: Time.current,
      ended_at: Time.current + 25.seconds,
      duration_seconds: 25,
      sentiment: sentiment,
      detected_intent: "Mobil Sesli Bilet Talebi",
      ai_summary: summary,
      ai_action_items: suggested_action,
      transcript_full: "MUSTERI: #{transcript}\nAI_BOT: Talebinizi aldım, biletinizi açtım."
    )

    # 5. Mobilde Yapay Zekanın Müşteriye Seslendireceği Yanıt
    spoken_ai_reply = "Merhaba Sayın #{customer.name}, ilettiğiniz talebi aldım ve #{ticket.formatted_number} numaralı destek biletinizi açtım. Uzman ekibimiz sorununuzu çözdüğünde bu mobil uygulama üzerinden sizi sesli olarak arayacağız."

    render json: {
      success: true,
      message: "Bilet başarıyla oluşturuldu.",
      ticket: {
        id: ticket.id,
        number: ticket.formatted_number,
        subject: ticket.subject,
        status: ticket.status,
        priority: ticket.priority,
        sentiment: ticket.ai_sentiment,
        ai_summary: ticket.ai_summary,
        created_at: ticket.created_at.strftime("%H:%M - %d.%m.%Y")
      },
      ai_reply: spoken_ai_reply
    }
  rescue StandardError => e
    Rails.logger.error("Mobile Voice Ticket Error: #{e.message}")
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # 2. Canlı Karşılıklı Telefon Görüşmesi (Interactive Phone Call Dialogue)
  def conversational_call
    action = params[:call_action].presence || "chat" # "start" | "chat" | "hangup"
    caller_name = params[:customer_name].presence || "Emre Kaan"
    caller_phone = params[:customer_phone].presence || "+90 554 720 0828"
    messages = params[:messages] || []

    org = current_organization || Organization.first
    customer = User.find_by(phone: caller_phone) || 
               User.find_by(email: "musteri@acme.com") ||
               User.create!(
                 organization: org,
                 name: caller_name,
                 email: "mobil_#{SecureRandom.hex(4)}@acme.com",
                 phone: caller_phone,
                 role: "customer",
                 password: "password123"
               )

    ai_service = AzureOpenAiService.new

    if action == "start"
      # Çağrı ilk bağlandığında Selin'in selamlama cümlesi
      initial_speech = "İyi günler #{caller_name} Bey, Acme Müşteri Hizmetlerine hoş geldiniz. Ben yapay zeka temsilciniz Selin. Size bugün nasıl yardımcı olabilirim?"
      return render json: {
        success: true,
        ai_reply: initial_speech,
        ticket_created: false
      }
    end

    # Karşılıklı konuşma
    ai_reply = ai_service.interactive_agent_chat(messages, customer_name: caller_name)

    # Konuşma içinde bilet oluşturulması gerekip gerekmediğini veya kullanıcının talebini kontrol et
    full_transcript = messages.map { |m| "#{m['role'] == 'user' ? caller_name : 'Selin (AI)'}: #{m['content']}" }.join("\n")
    user_messages_count = messages.select { |m| m["role"] == "user" }.count

    ticket_created = false
    ticket_payload = nil

    # En az 1 kullanıcı mesajı varsa ve talep olgunlaşmışsa bilet aç
    should_create = (user_messages_count >= 1 && (ai_reply.downcase.include?("bilet") || ai_reply.downcase.include?("kayd") || ai_reply.downcase.include?("aldım") || action == "hangup"))

    if should_create && !params[:existing_ticket_id].present?
      ai_analysis = ai_service.analyze_call_transcript(full_transcript, { name: caller_name, phone: caller_phone })
      
      subject = ai_analysis["intent"].presence || "Mobil Sesli Görüşme Talebi"
      priority = %w[low normal high urgent].include?(ai_analysis["suggested_priority"]) ? ai_analysis["suggested_priority"] : "normal"
      sentiment = ai_analysis["sentiment"] || "neutral"
      summary = ai_analysis["summary"] || full_transcript
      suggested_action = ai_analysis["action_items"]

      ticket = org.tickets.create!(
        subject: subject,
        description: full_transcript,
        status: "new",
        priority: priority,
        ticket_type: "incident",
        channel: "mobile",
        requester: customer,
        ai_sentiment: sentiment,
        ai_summary: summary,
        ai_suggested_action: suggested_action
      )

      duration = [params[:duration_seconds].to_i, 12].max
      org.call_logs.create!(
        call_sid: "mobile-call-#{SecureRandom.hex(6)}",
        caller_number: caller_phone,
        callee_number: org.phone_number_formatted,
        caller_name: caller_name,
        ticket: ticket,
        direction: "inbound",
        status: "completed",
        started_at: Time.current - duration.seconds,
        ended_at: Time.current,
        duration_seconds: duration,
        sentiment: sentiment,
        detected_intent: subject,
        ai_summary: summary,
        ai_action_items: suggested_action,
        transcript_full: full_transcript + "\nSelin (AI): #{ai_reply}"
      )

      ticket_created = true
      ticket_payload = {
        id: ticket.id,
        number: ticket.formatted_number,
        subject: ticket.subject,
        status: ticket.status,
        priority: ticket.priority,
        sentiment: ticket.ai_sentiment
      }
    end

    render json: {
      success: true,
      ai_reply: ai_reply,
      ticket_created: ticket_created,
      ticket: ticket_payload
    }
  rescue StandardError => e
    Rails.logger.error("Conversational Call Error: #{e.message}")
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # 2b. Canlı Mikrofon Ses Dosyasını (Hands-free Voice) Transkribe Et ve Yanıtla
  def conversational_audio
    caller_name = params[:customer_name].presence || "Emre Kaan"
    caller_phone = params[:customer_phone].presence || "+90 554 720 0828"
    raw_messages = params[:messages]
    messages = raw_messages.is_a?(String) ? (JSON.parse(raw_messages) rescue []) : (raw_messages || [])

    # 1. Ses Verisini Al
    audio_data = if params[:audio_base64].present?
                   clean_b64 = params[:audio_base64].to_s.sub(/\Adata:.*?;base64,/, "")
                   Base64.decode64(clean_b64)
                 elsif params[:audio].present?
                   params[:audio].read
                 end

    Rails.logger.info("Conversational Audio: Received #{audio_data&.bytesize} bytes from #{caller_name}")

    if audio_data.blank?
      return render json: { success: false, recognized: false, error: "Ses verisi bulunamadı." }
    end

    # 2. Azure Speech Services ile Türkçe Ses Çözümleme (Speech-to-Text)
    transcribed_text = AzureSpeechService.transcribe_audio(audio_data, "audio/mp4")
    Rails.logger.info("Conversational Audio: Transcription => '#{transcribed_text}'")

    if transcribed_text.blank?
      return render json: {
        success: true,
        recognized: false,
        message: "Ses net algılanamadı veya sessizlik oldu."
      }
    end

    # 3. Transkribe edilen metni kullanıcı mesajı olarak ekle
    updated_messages = messages + [{ "role" => "user", "content" => transcribed_text }]

    # 4. Azure OpenAI ile Selin'in Yanıtını Üret
    ai_service = AzureOpenAiService.new
    ai_reply = ai_service.interactive_agent_chat(updated_messages, customer_name: caller_name)

    # 5. Bilet Oluşturulması Gerekiyor mu Kontrol Et
    org = current_organization || Organization.first
    customer = User.find_by(phone: caller_phone) || 
               User.find_by(email: "musteri@acme.com") ||
               User.create!(
                 organization: org,
                 name: caller_name,
                 email: "mobil_#{SecureRandom.hex(4)}@acme.com",
                 phone: caller_phone,
                 role: "customer",
                 password: "password123"
               )

    full_transcript = updated_messages.map { |m| "#{m['role'] == 'user' ? caller_name : 'Selin (AI)'}: #{m['content']}" }.join("\n")
    user_count = updated_messages.select { |m| m["role"] == "user" }.count
    should_create = (user_count >= 1 && (ai_reply.downcase.include?("bilet") || ai_reply.downcase.include?("kayd") || ai_reply.downcase.include?("aldım")))

    ticket_created = false
    ticket_payload = nil

    if should_create && !params[:existing_ticket_id].present?
      ai_analysis = ai_service.analyze_call_transcript(full_transcript, { name: caller_name, phone: caller_phone })
      subject = ai_analysis["intent"].presence || "Mobil Sesli Görüşme Talebi"
      priority = %w[low normal high urgent].include?(ai_analysis["suggested_priority"]) ? ai_analysis["suggested_priority"] : "normal"
      sentiment = ai_analysis["sentiment"] || "neutral"
      summary = ai_analysis["summary"] || full_transcript
      suggested_action = ai_analysis["action_items"]

      ticket = org.tickets.create!(
        subject: subject,
        description: full_transcript,
        status: "new",
        priority: priority,
        ticket_type: "incident",
        channel: "mobile",
        requester: customer,
        ai_sentiment: sentiment,
        ai_summary: summary,
        ai_suggested_action: suggested_action
      )

      duration = [params[:duration_seconds].to_i, 15].max
      org.call_logs.create!(
        call_sid: "mobile-call-#{SecureRandom.hex(6)}",
        caller_number: caller_phone,
        callee_number: org.phone_number_formatted,
        caller_name: caller_name,
        ticket: ticket,
        direction: "inbound",
        status: "completed",
        started_at: Time.current - duration.seconds,
        ended_at: Time.current,
        duration_seconds: duration,
        sentiment: sentiment,
        detected_intent: subject,
        ai_summary: summary,
        ai_action_items: suggested_action,
        transcript_full: full_transcript + "\nSelin (AI): #{ai_reply}"
      )

      ticket_created = true
      ticket_payload = {
        id: ticket.id,
        number: ticket.formatted_number,
        subject: ticket.subject,
        status: ticket.status,
        priority: ticket.priority,
        sentiment: ticket.ai_sentiment
      }
    end

    render json: {
      success: true,
      recognized: true,
      user_transcript: transcribed_text,
      ai_reply: ai_reply,
      ticket_created: ticket_created,
      ticket: ticket_payload
    }
  rescue StandardError => e
    Rails.logger.error("Conversational Audio Error: #{e.message}")
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # 3. Müşterinin Biletlerini Listeleme
  def tickets
    org = current_organization || Organization.first
    tickets = org.tickets.recent.limit(20).map do |t|
      {
        id: t.id,
        number: t.formatted_number,
        subject: t.subject,
        status: t.status,
        status_label: case t.status
                      when "new" then "Yeni Talep"
                      when "open" then "İnceleniyor"
                      when "pending" then "İşlemde"
                      when "solved" then "Çözüldü"
                      when "closed" then "Kapatıldı"
                      else t.status
                      end,
        priority: t.priority,
        sentiment: t.ai_sentiment,
        ai_summary: t.ai_summary,
        solution: t.ai_suggested_action,
        created_at: t.created_at.strftime("%H:%M - %d.%m.%Y")
      }
    end

    render json: { success: true, tickets: tickets }
  end

  # 4. Gelen Arama Kontrolü (Admin Web'den 'Çöz & Geri Ara' Dedi mi?)
  def check_call
    org = current_organization || Organization.first

    # SADECE ve SADECE 'ringing' (çalan) durumundaki outbound çağrıyı al!
    # 'in_progress', 'answered' veya 'completed' çağrılar ASLA tekrar arama olarak görünmez!
    ringing_call = org.call_logs.where(direction: "outbound", status: "ringing")
                               .where("created_at > ?", 5.minutes.ago)
                               .order(created_at: :desc).first

    if ringing_call && ringing_call.ticket.present?
      target_ticket = ringing_call.ticket
      call_unique_id = "call-#{ringing_call.id}"

      handled_call_id = params[:handled_call_id].to_s
      if handled_call_id == call_unique_id
        return render json: { has_incoming_call: false }
      end

      solution_text = target_ticket.ai_suggested_action.presence || target_ticket.description.to_s.truncate(140)
      customer_name = target_ticket.requester&.name || "Değerli Müşterimiz"
      
      spoken_message = "İyi günler Sayın #{customer_name}, ben Acme müşteri temsilciniz Selin. #{target_ticket.formatted_number} numaralı destek talebiniz uzman ekibimiz tarafından incelenmiş ve çözüme kavuşturulmuştur. Çözüm detayınız: #{solution_text}. Bu konuyla ilgili aklınıza takılan başka bir soru veya yardımcı olabileceğim bir durum var mı?"

      render json: {
        has_incoming_call: true,
        call: {
          id: call_unique_id,
          call_id: ringing_call.id,
          ticket_id: target_ticket.id,
          ticket_number: target_ticket.formatted_number,
          ticket_subject: target_ticket.subject,
          customer_name: customer_name,
          speech_text: spoken_message,
          spoken_message: spoken_message,
          solution_summary: solution_text
        }
      }
    else
      render json: { has_incoming_call: false }
    end
  end

  # 5. Aramayı Cevaplama & Kapatma
  def answer_call
    org = current_organization || Organization.first
    # Müşteri çağrıyı yanıtladığı anda status 'answered' yapılır; böylece ASLA TEKRAR ÇALMAZ!
    if params[:call_id].present?
      CallLog.find_by(id: params[:call_id])&.update(status: "answered")
    elsif params[:ticket_id].present?
      org.call_logs.where(ticket_id: params[:ticket_id], direction: "outbound").update_all(status: "answered")
    else
      org.call_logs.where(direction: "outbound", status: "ringing").update_all(status: "answered")
    end
    render json: { success: true, status: "in_call" }
  end

  def end_call
    org = current_organization || Organization.first
    if params[:call_id].present?
      CallLog.find_by(id: params[:call_id])&.update(status: "completed")
    elsif params[:ticket_id].present?
      org.call_logs.where(ticket_id: params[:ticket_id], direction: "outbound").update_all(status: "completed")
    else
      org.call_logs.where(direction: "outbound", status: ["ringing", "answered"]).update_all(status: "completed")
    end
    render json: { success: true, status: "call_ended" }
  end

  def trigger_test_callback
    org = current_organization || Organization.first
    ticket = org.tickets.where(status: "solved").order(updated_at: :desc).first || org.tickets.order(updated_at: :desc).first
    if ticket
      OutboundCallService.trigger_resolution_call(ticket)
      render json: { success: true, message: "Geri arama başlatıldı", ticket_id: ticket.id }
    else
      render json: { success: false, message: "Bilet bulunamadı" }
    end
  end

  private

  def set_cors_headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, X-Requested-With'
  end
end
