class CallCenterController < ApplicationController
  skip_before_action :authenticate_user!, only: [:webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook, :simulate_incoming_call, :create_from_voice, :custom_incoming_call]

  def index
    @calls = current_organization.call_logs.recent
    @active_calls = current_organization.call_logs.active.recent
    @completed_calls = current_organization.call_logs.where(status: "completed").recent
    
    # Call Center Analytics
    @total_calls = @calls.count
    @total_duration = @calls.sum(:duration_seconds)
    @avg_duration_formatted = @total_calls.positive? ? format("%02d:%02d", (@total_duration / @total_calls) / 60, (@total_duration / @total_calls) % 60) : "00:00"
    @positive_sentiment_count = @calls.where(sentiment: "positive").count
    @negative_sentiment_count = @calls.where(sentiment: %w[negative frustrated]).count
    @neutral_sentiment_count = @calls.where(sentiment: %w[neutral nil]).count
  end

  def softphone
    @agent = current_user
    @acs_service = AzureCommunicationService.new
    @webrtc_token = @acs_service.generate_agent_token(@agent)
    @recent_calls = current_organization.call_logs.recent.limit(5)
    @latest_call = current_organization.call_logs.first
  end

  # Channels > Talk > Numbers: Phone Number and PSTN/Webhook configuration
  def numbers
    @organization = current_organization
    @recent_calls = current_organization.call_logs.recent.limit(10)
    @webhook_url = "#{request.base_url}/call_center/webhook"
    @acs_phone_number = ENV["AZURE_COMMUNICATION_PHONE_NUMBER"].presence || @organization.phone_number_formatted
  end

  # Updates organization phone number and IVR greeting
  def update_number
    @organization = current_organization
    new_phone = params[:phone_number].to_s.strip
    ivr_text = params[:ivr_greeting].to_s.strip

    settings = @organization.settings || {}
    settings["ivr_greeting"] = ivr_text if ivr_text.present?

    if @organization.update(phone_number: new_phone, settings: settings)
      redirect_to call_center_numbers_path, notice: "✅ Santral telefon numarası (#{new_phone}) ve IVR ayarları başarıyla güncellendi."
    else
      redirect_to call_center_numbers_path, alert: "Numara güncellenirken hata oluştu."
    end
  end

  # Direct Incoming Call Simulator from ANY customer phone number
  def custom_incoming_call
    caller_name = params[:caller_name].presence || "Bilinmeyen Müşteri"
    caller_phone = params[:caller_phone].presence || "+90 532 999 0001"
    customer_issue = params[:customer_issue].presence || "Merhaba, aldığım hizmetle ilgili teknik destek almak istiyorum."
    ivr_greeting = current_organization.ivr_greeting

    # 1. Create CallLog
    call_log = current_organization.call_logs.create!(
      call_sid: "pstn-inbound-#{SecureRandom.hex(6)}",
      caller_number: caller_phone,
      callee_number: current_organization.phone_number_formatted,
      caller_name: caller_name,
      agent: current_user,
      direction: "inbound",
      status: "in_progress",
      started_at: Time.current
    )

    # 2. Add transcript dialogue
    call_log.call_transcripts.create!(
      speaker: "ai_bot",
      content: ivr_greeting,
      sentiment: "neutral",
      offset_ms: 1000
    )

    call_log.call_transcripts.create!(
      speaker: "customer",
      content: customer_issue,
      sentiment: "neutral",
      offset_ms: 6000
    )

    confirmation_text = "Talebinizi aldım, çağrı merkezi yapay zeka sistemimiz biletinizi oluşturuyor ve yetkili ekibe aktarıyor."
    call_log.call_transcripts.create!(
      speaker: "ai_bot",
      content: confirmation_text,
      sentiment: "positive",
      offset_ms: 12000
    )

    full_text = "AI_BOT: #{ivr_greeting}\nMUSTERI: #{customer_issue}\nAI_BOT: #{confirmation_text}\n"
    call_log.update_column(:transcript_full, full_text)

    # 3. Finalize Call through Microsoft Call Center AI Pipeline
    call_log.update(status: "completed", ended_at: Time.current, duration_seconds: 35)
    ticket = CallCenterAiPipeline.finalize_call(call_log)

    redirect_to ticket_path(ticket), notice: "📞 Müşteri (#{caller_phone}) santral numaranızı (#{current_organization.phone_number_formatted}) aradı! Görüşme kaydedildi, Azure AI ile analiz edildi ve Bilet ##{ticket.ticket_number} oluşturuldu."
  end

  # Live simulation of an incoming call with Microsoft Call Center AI
  def simulate_incoming_call
    scenario = params[:scenario] || "fatura"

    scenario_data = case scenario
                    when "iptal"
                      {
                        caller_name: "Zeynep Çelik (Startup.io)",
                        caller_number: "+90 542 987 6543",
                        dialogue: [
                          { speaker: "ai_bot", text: "Acme Destek Hattına hoş geldiniz. Ben AI Asistanınız. Nasıl yardımcı olabilirim?", sentiment: "neutral" },
                          { speaker: "customer", text: "Merhaba, yıllık yenileme öncesi aboneliğimizi iptal etmek istiyoruz.", sentiment: "neutral" },
                          { speaker: "ai_bot", text: "Abonelik ve hesap yönetimi uzmanımıza hemen aktarıyorum.", sentiment: "neutral" },
                          { speaker: "agent", text: "Merhabalar Zeynep Hanım, ben Can. İptal kararınızın özel bir sebebi var mı, yardımcı olabilir miyim?", sentiment: "positive" },
                          { speaker: "customer", text: "Bütçemiz daraldı, biraz daha uygun bir alternatif arıyoruz.", sentiment: "neutral" },
                          { speaker: "agent", text: "Sizin için mevcut paketinizi 6 ay boyunca %30 indirimle devam ettirebilirim.", sentiment: "positive" },
                          { speaker: "customer", text: "Bu teklif çok iyi oldu, iptalden vazgeçiyoruz o halde, teşekkürler!", sentiment: "positive" }
                        ]
                      }
                    when "teknik"
                      {
                        caller_name: "Mehmet Öz (Fintech.net)",
                        caller_number: "+90 530 456 7890",
                        dialogue: [
                          { speaker: "ai_bot", text: "Acme Cloud AI Asistanı devrede. Talebinizi iletebilirsiniz.", sentiment: "neutral" },
                          { speaker: "customer", text: "Canlı ortamda API isteklerimiz 504 Gateway Timeout vermeye başladı, kritik durum!", sentiment: "frustrated" },
                          { speaker: "ai_bot", text: "Kritik teknik arıza tespit edildi. Seviye 2 sistem mühendisine yönlendiriliyorsunuz.", sentiment: "neutral" },
                          { speaker: "agent", text: "Mehmet Bey merhaba, altyapı ekibi olarak hattayız. IP adresinizi hemen kontrol ediyorum.", sentiment: "positive" },
                          { speaker: "customer", text: "Statik IP adresimiz 185.122.40.11, lütfen firewall kontrolü yapın.", sentiment: "negative" },
                          { speaker: "agent", text: "Güvenlik kuralı güncellendi ve kısıtlama kaldırıldı. Şimdi test edebilir misiniz?", sentiment: "positive" },
                          { speaker: "customer", text: "Harika, istekler 200 OK dönmeye başladı. Çok teşekkür ederim.", sentiment: "positive" }
                        ]
                      }
                    else # fatura
                      {
                        caller_name: "Ahmet Kaya (TechCorp)",
                        caller_number: "+90 555 123 4567",
                        dialogue: [
                          { speaker: "ai_bot", text: "Acme Destek Hattına hoş geldiniz. Ben sesli yapay zeka asistanınız.", sentiment: "neutral" },
                          { speaker: "customer", text: "Kredi kartımdan mükerrer 450 TL çekim yapılmış, iadesini talep ediyorum.", sentiment: "negative" },
                          { speaker: "ai_bot", text: "Fatura itirazınız için finans yetkilimiz Can Bey'e aktarıyorum.", sentiment: "neutral" },
                          { speaker: "agent", text: "Ahmet Bey merhaba, itirazınızı inceledim. Banka provizyon tekrarı nedeniyle oluşmuş.", sentiment: "positive" },
                          { speaker: "customer", text: "Ne zaman karta geri yansır peki?", sentiment: "neutral" },
                          { speaker: "agent", text: "İade talimatını verdim, 2 iş günü içinde kartınıza yansıyacaktır.", sentiment: "positive" },
                          { speaker: "customer", text: "Çok teşekkür ederim hızlı çözümünüz için.", sentiment: "positive" }
                        ]
                      }
                    end

    # 1. Create CallLog
    call_log = current_organization.call_logs.create!(
      call_sid: "acs-live-#{SecureRandom.hex(6)}",
      caller_number: scenario_data[:caller_number],
      callee_number: current_organization.phone_number || "+90 850 300 4050",
      caller_name: scenario_data[:caller_name],
      agent: current_user,
      direction: "inbound",
      status: "in_progress",
      started_at: Time.current
    )

    # 2. Add transcript chunks
    cumulative_text = ""
    scenario_data[:dialogue].each_with_index do |d, idx|
      call_log.call_transcripts.create!(
        speaker: d[:speaker],
        content: d[:text],
        sentiment: d[:sentiment],
        offset_ms: (idx + 1) * 3500
      )
      cumulative_text += "#{d[:speaker].upcase}: #{d[:text]}\n"
    end
    call_log.update_column(:transcript_full, cumulative_text)

    # 3. Finalize Call through Microsoft Call Center AI Pipeline
    call_log.update(status: "completed", ended_at: Time.current, duration_seconds: scenario_data[:dialogue].length * 15)
    ticket = CallCenterAiPipeline.finalize_call(call_log)

    redirect_to ticket_path(ticket), notice: "🎙️ Microsoft Call Center AI çağrısı simüle edildi! Transkript analiz edildi ve Bilet ##{ticket.ticket_number} oluşturuldu."
  end

  # Creates a real ticket from the user's actual microphone voice transcript
  def create_from_voice
    transcript = params[:transcript].to_s.strip
    transcript = "Kullanıcı mikrofondan sesli talep iletti: " + transcript if transcript.present?
    transcript = "Müşteri mikrofonuyla konuştu ancak ses algılanamadı." if transcript.blank?

    caller_name = params[:caller_name].presence || "#{current_user.name} (Sesli Talep)"
    caller_phone = params[:caller_phone].presence || current_user.phone || "+90 532 999 0001"

    call_log = current_organization.call_logs.create!(
      call_sid: "live-mic-#{SecureRandom.hex(6)}",
      caller_number: caller_phone,
      callee_number: current_organization.phone_number || "+90 850 300 4050",
      caller_name: caller_name,
      agent: current_user,
      direction: "inbound",
      status: "completed",
      duration_seconds: params[:duration_seconds].to_i.positive? ? params[:duration_seconds].to_i : 35,
      started_at: Time.current,
      ended_at: Time.current,
      transcript_full: transcript
    )

    # Insert single transcript record
    call_log.call_transcripts.create!(
      speaker: "customer",
      content: transcript,
      sentiment: "neutral"
    )

    # Finalize with real Azure OpenAI GPT-4o analysis
    ticket = CallCenterAiPipeline.finalize_call(call_log)
    voice_response = "Talebinizi aldım. #{ticket.formatted_number} numaralı biletiniz başarıyla oluşturuldu ve çözüm ekibimize iletildi. Ekibimiz sorunu çözdüğünde sizi telefonla geri arayarak bilgilendirecektir."

    respond_to do |format|
      format.html { redirect_to ticket_path(ticket), notice: "🎙️ Sesiniz Azure OpenAI GPT-4o ile analiz edildi ve Bilet ##{ticket.ticket_number} oluşturuldu!" }
      format.json do
        render json: {
          status: "success",
          ticket_id: ticket.id,
          ticket_number: ticket.ticket_number,
          voice_response: voice_response,
          redirect_url: ticket_path(ticket)
        }
      end
    end
  end

  # Triggers manual AI analysis on any existing call log
  def trigger_ai_analysis
    call_log = current_organization.call_logs.find(params[:id])
    ticket = CallCenterAiPipeline.finalize_call(call_log)
    redirect_to ticket_path(ticket), notice: "Yapay zeka analizi tamamlandı ve bilet güncellendi."
  end

  # ACS Token endpoint
  def token
    service = AzureCommunicationService.new
    render json: service.generate_agent_token(current_user)
  end

  # Azure Communication Services Webhook endpoint
  def webhook
    service = AzureCommunicationService.new
    event_type = request.headers["aeg-event-type"] || params[:event_type] || "call.ended"
    payload = params.to_unsafe_h

    # Azure EventGrid Webhook Validation Handshake
    if event_type == "SubscriptionValidation"
      validation_code = payload.dig("data", "validationCode")
      return render json: { validationResponse: validation_code }
    end

    call_log = service.handle_webhook_event(event_type, payload)
    render json: { status: "received", call_id: call_log&.id }
  end
end
