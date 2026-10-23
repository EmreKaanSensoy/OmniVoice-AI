require "httparty"

class AzureOpenAiService
  include HTTParty

  def initialize(organization: nil)
    @organization = organization
    endpoint_raw = ENV["AZURE_OPENAI_ENDPOINT"].to_s.strip
    # Strip any trailing slashes or subpaths if user copied full target URI
    @endpoint = if endpoint_raw.include?("/openai")
                  endpoint_raw.split("/openai").first.chomp("/")
                else
                  endpoint_raw.chomp("/")
                end
    @endpoint = "https://your-resource.openai.azure.com" if @endpoint.to_s.empty?
    @api_key = ENV["AZURE_OPENAI_API_KEY"].to_s.strip
    @deployment_id = ENV["AZURE_OPENAI_DEPLOYMENT"].to_s.strip
    @deployment_id = "gpt-4o" if @deployment_id.empty?
    @api_version = ENV["AZURE_OPENAI_API_VERSION"].to_s.strip
    @api_version = "2024-08-01-preview" if @api_version.empty?
  end

  # Analyzes full transcript to generate:
  # - Ticket summary
  # - Action items
  # - Detected intent
  # - Sentiment (positive, neutral, negative, frustrated)
  # - Suggested tags
  def analyze_call_transcript(transcript_text, caller_info = {})
    return mock_call_analysis(transcript_text, caller_info) if @api_key.to_s.empty?

    url = "#{@endpoint}/openai/deployments/#{@deployment_id}/chat/completions?api-version=#{@api_version}"
    headers = {
      "Content-Type" => "application/json",
      "api-key" => @api_key
    }

    system_prompt = <<~PROMPT
      Sen kurumsal bir çağrı merkezi yapay zeka analistisin (Zendesk & Microsoft Call Center AI).
      Görüşme transkriptini analiz edip geçerli bir JSON formatında şu anahtarları döndür:
      {
        "summary": "Müşteri sorunu, yapılan işlem ve varılan sonucu özetleyen 2-3 cümle",
        "action_items": "Temsilcinin veya ilgili birimin yapması gereken takip maddeleri",
        "intent": "Müşterinin ana arama amacı (örn: Fatura İtirazı, Teknik Destek, İade Talebi, Abonelik İptali)",
        "sentiment": "positive | neutral | negative | frustrated",
        "tags": ["fatura", "iade", "onay_bekliyor"],
        "suggested_ticket_status": "open | pending | solved",
        "suggested_priority": "low | normal | high | urgent"
      }
      SADECE JSON döndür.
    PROMPT

    user_prompt = "Müşteri: #{caller_info[:name] || 'Bilinmiyor'} (#{caller_info[:phone]})\n\nTranskript:\n#{transcript_text}"

    body = {
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ],
      temperature: 0.2,
      response_format: { type: "json_object" }
    }.to_json

    response = self.class.post(url, headers: headers, body: body, timeout: 15)

    if response.success?
      parsed = JSON.parse(response.body)
      content = parsed.dig("choices", 0, "message", "content")
      JSON.parse(content)
    else
      msg = "Azure OpenAI Error: #{response.code} #{response.body}"
      defined?(Rails) && Rails.logger ? Rails.logger.error(msg) : warn(msg)
      mock_call_analysis(transcript_text, caller_info)
    end
  rescue StandardError => e
    msg = "Azure OpenAI Exception: #{e.message}"
    defined?(Rails) && Rails.logger ? Rails.logger.error(msg) : warn(msg)
    mock_call_analysis(transcript_text, caller_info)
  end

  # Real-time Agent Assist: generates quick macro recommendations and helpful responses during live call
  def suggest_agent_response(recent_chunks, current_ticket = nil)
    return mock_agent_suggestion(recent_chunks) if @api_key.to_s.empty?

    url = "#{@endpoint}/openai/deployments/#{@deployment_id}/chat/completions?api-version=#{@api_version}"
    headers = {
      "Content-Type" => "application/json",
      "api-key" => @api_key
    }

    system_prompt = <<~PROMPT
      Sen canlı çağrı esnasında temsilciye gerçek zamanlı fısıldayan (Agent Copilot) yapay zekasın.
      Son konuşulanlara göre temsilciye HEMEN kullanabileceği 1 cümlelik en uygun yanıt önerisini ve önerilen aksiyonu JSON döndür:
      {
        "suggested_reply": "Müşteriye söylenebilecek kibar ve çözüm odaklı yanıt",
        "recommended_action": "Sistemde yapılması gereken işlem (örn: Fatura dökümü aç, 150 TL iade formunu doldur)",
        "knowledge_reference": "İlgili destek makalesi başlığı"
      }
    PROMPT

    chunks_text = recent_chunks.map { |c| "#{c[:speaker]}: #{c[:content]}" }.join("\n")

    body = {
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: chunks_text }
      ],
      temperature: 0.3,
      response_format: { type: "json_object" }
    }.to_json

    response = self.class.post(url, headers: headers, body: body, timeout: 5)

    if response.success?
      parsed = JSON.parse(response.body)
      content = parsed.dig("choices", 0, "message", "content")
      JSON.parse(content)
    else
      mock_agent_suggestion(recent_chunks)
    end
  rescue StandardError => e
    mock_agent_suggestion(recent_chunks)
  end

  # Interactive customer call dialogue
  def interactive_agent_chat(messages, customer_name: "Emre Bey")
    return "Anlıyorum #{customer_name}, talebinizi aldım. Hemen destek biletinizi açıyorum." if @api_key.to_s.empty?

    url = "#{@endpoint}/openai/deployments/#{@deployment_id}/chat/completions?api-version=#{@api_version}"
    headers = {
      "Content-Type" => "application/json",
      "api-key" => @api_key
    }

    system_prompt = <<~PROMPT
      Sen kurumsal bir çağrı merkezinde (Acme Destek) görev yapan, son derece kibar, profesyonel, empatik ve Türkçe konuşan yapay zeka müşteri temsilcisi Selin'sin.
      Şu an #{customer_name} isimli müşteriyle canlı bir telefon görüşmesi yapıyorsun.
      
      GÖREV VE KURALLAR:
      1. Bir telefon görüşmesinde olduğun için konuşma dilin samimi, doğal ve kısa olmalı (en fazla 2-3 akıcı cümle). Asla uzun listeler veya paragraflar kurma.
      2. Müşterinin adını ara sıra kullanarak ona güven ver.
      3. Müşterinin talebini veya sorununu dikkatle dinle. Gerekirse tek bir soru sorarak netleştir.
      4. Müşteri sorununu anlattığında veya talebi netleştiğinde, "Talebinizi aldım, destek biletinizi oluşturdum." diyerek ekibe ilettiğini söyle.
    PROMPT

    chat_messages = [{ role: "system", content: system_prompt }]
    (messages || []).each do |msg|
      r = (msg[:role] || msg["role"]).to_s
      c = (msg[:content] || msg["content"]).to_s
      chat_messages << { role: r, content: c } if c.present?
    end

    body = {
      messages: chat_messages,
      temperature: 0.7,
      max_tokens: 250
    }.to_json

    response = self.class.post(url, headers: headers, body: body, timeout: 15)

    if response.success?
      parsed = JSON.parse(response.body)
      parsed.dig("choices", 0, "message", "content")
    else
      "Anlıyorum #{customer_name}, konuyu not aldım. İlgili birimimize biletinizi hemen oluşturuyorum."
    end
  rescue StandardError => e
    Rails.logger.error("Azure OpenAI interactive chat error: #{e.message}")
    "Anlıyorum #{customer_name}, talebinizi aldım. Hemen biletinizi oluşturuyorum."
  end

  private

  def mock_call_analysis(transcript_text, caller_info)
    has_invoice = transcript_text.to_s.downcase.include?("fatura") || transcript_text.to_s.downcase.include?("ücret") || transcript_text.to_s.downcase.include?("para")
    has_cancel = transcript_text.to_s.downcase.include?("iptal")

    if has_invoice
      {
        "summary" => "Müşteri son dönem ekstresinde beklenmeyen ek ücret yansıdığını belirtti. Temsilci faturayı inceleyerek mükerrer çekim tespit etti ve muhasebe onaylı 149 TL iade sürecini başlattı.",
        "action_items" => "1. Finans birimine #INV-8842 nolu iade kaydı iletildi.\n2. 48 saat içinde müşteri SMS ile bilgilendirilecek.",
        "intent" => "Hatalı Fatura İtirazı & İade Talebi",
        "sentiment" => "negative",
        "tags" => ["fatura", "iade-onayı", "azure-call-ai", "öncelikli"],
        "suggested_ticket_status" => "pending",
        "suggested_priority" => "high"
      }
    elsif has_cancel
      {
        "summary" => "Müşteri paket yenileme dönemi öncesinde hizmet iptali talebinde bulundu. Temsilci memnuniyetsizlik nedenlerini dinleyip %20 indirimli alternatif plan sundu.",
        "action_items" => "Abonelik durumu 'İptal İncelemesi' olarak işaretlendi. Müşteri teklifi değerlendirecek.",
        "intent" => "Abonelik İptal Talebi",
        "sentiment" => "neutral",
        "tags" => ["abonelik", "iptal-riski", "indirim-teklifi"],
        "suggested_ticket_status" => "open",
        "suggested_priority" => "urgent"
      }
    else
      {
        "summary" => "Müşteri hesap erişimi ve yeni özellikleri öğrenmek için aradı. Temsilci adım adım rehberlik sağladı ve ilgili bilgi bankası dokümanını bilet üzerinden paylaştı.",
        "action_items" => "Ek bir aksiyon gerekmiyor. Kullanıcı işlemi başarıyla tamamladı.",
        "intent" => "Genel Teknik Destek & Kullanım Bilgisi",
        "sentiment" => "positive",
        "tags" => ["teknik-destek", "cozum-saglandi", "azure-call-ai"],
        "suggested_ticket_status" => "solved",
        "suggested_priority" => "normal"
      }
    end
  end

  def mock_agent_suggestion(recent_chunks)
    {
      "suggested_reply" => "Müşteri son faturadaki tutara itiraz etti. Yanıt: 'Ekstrenizi hemen kontrol ediyorum, mükerrer tahsilat söz konusuysa onayınızla anında iade oluşturabilirim.'",
      "recommended_action" => "Faturalandırma sekmesinden son işlemi 'Ters Kayıt (Chargeback)' olarak işaretleyin.",
      "knowledge_reference" => "Makale: Hatalı Tahsilat İade Prosedürü (KB-104)"
    }
  end
end
