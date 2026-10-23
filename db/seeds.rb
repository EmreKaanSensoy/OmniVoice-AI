puts "== Seeding Zendesk Clone & Microsoft Call Center AI =="

Organization.destroy_all
User.destroy_all
Ticket.destroy_all
CallLog.destroy_all
KnowledgeArticle.destroy_all
Macro.destroy_all

# 1. Organization
org = Organization.create!(
  name: "Acme Global Destek",
  subdomain: "acme",
  phone_number: "+90 850 300 4050",
  settings: {
    theme: "dark",
    ai_auto_summary: true,
    ai_realtime_transcription: true,
    call_recording_enabled: true
  }
)

# 2. Users
admin = User.create!(
  organization: org,
  name: "Sarah Jenkins (Yönetici)",
  email: "admin@acme.com",
  password: "password123",
  role: "admin",
  phone: "+90 532 999 0001",
  status: "available",
  avatar_url: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120"
)

agent1 = User.create!(
  organization: org,
  name: "Can Yılmaz (Destek Temsilcisi)",
  email: "agent@acme.com",
  password: "password123",
  role: "agent",
  phone: "+90 532 999 0002",
  status: "available",
  avatar_url: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120"
)

agent2 = User.create!(
  organization: org,
  name: "Elif Demir (Kıdemli Temsilci)",
  email: "elif@acme.com",
  password: "password123",
  role: "agent",
  phone: "+90 532 999 0003",
  status: "available",
  avatar_url: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=120"
)

customer1 = User.create!(
  organization: org,
  name: "Ahmet Kaya",
  email: "ahmet@techcorp.com",
  password: "password123",
  role: "customer",
  phone: "+90 555 123 4567"
)

customer2 = User.create!(
  organization: org,
  name: "Zeynep Çelik",
  email: "zeynep@startup.io",
  password: "password123",
  role: "customer",
  phone: "+90 542 987 6543"
)

customer3 = User.create!(
  organization: org,
  name: "Mehmet Öz",
  email: "mehmet@fintech.net",
  password: "password123",
  role: "customer",
  phone: "+90 530 456 7890"
)

# 3. Knowledge Articles (Guide)
k1 = KnowledgeArticle.create!(
  organization: org,
  author: admin,
  title: "Fatura İtirazları ve İade Süreçleri",
  category: "Faturalandırma",
  body: "Müşterilerin ekstresinde tespit edilen mükerrer çekim durumlarında, finans paneli üzerinden 'Ters Kayıt' oluşturularak 48 saat içinde bankaya provizyon iadesi iletilir.",
  views_count: 142,
  helpful_count: 38
)

k2 = KnowledgeArticle.create!(
  organization: org,
  author: agent1,
  title: "Azure Communication Services WebRTC Softphone Kullanımı",
  category: "Sistem & Altyapı",
  body: "Temsilciler tarayıcı üzerinden gelen çağrıları kabul etmek için mikrofon izinlerini onaylamalıdır. Görüşme esnasında yapay zeka canlı olarak konuşmayı dinler ve yan panelde yanıt önerileri üretir.",
  views_count: 89,
  helpful_count: 24
)

k3 = KnowledgeArticle.create!(
  organization: org,
  author: admin,
  title: "API Webhook Entegrasyonu ve Hata Kodları",
  category: "Geliştirici Rehberi",
  body: "Webhook çağrılarında 502/504 hataları genellikle uç nokta zaman aşımından kaynaklanır. Maksimum yanıt süresi 4000ms olarak sınırlandırılmıştır.",
  views_count: 210,
  helpful_count: 55
)

# 4. Macros
Macro.create!(
  organization: org,
  title: "Fatura İadesi Onayı Gönder",
  description: "İade onaylandı şablonunu uygular ve bilet durumunu çözüldü yapar.",
  actions: {
    add_comment: "İade talebiniz onaylanmış olup ilgili tutar 3 iş günü içinde kartınıza yansıyacaktır.",
    set_status: "solved",
    add_tags: ["iade-tamamlandi", "memnuniyet-takip"]
  }
)

Macro.create!(
  organization: org,
  title: "Teknik İnceleme Seviye 2'ye Aktar",
  description: "Bileti kıdemli mühendis grubuna yönlendirir ve önceliği acil yapar.",
  actions: {
    set_priority: "urgent",
    set_status: "open",
    add_internal_note: "Gelişmiş log incelemesi için Seviye 2 ekibine aktarıldı."
  }
)

# 5. Tickets & Ticket Comments
t1 = Ticket.create!(
  organization: org,
  subject: "SaaS Pro Plan faturalandırmasında mükerrer çekim hatası",
  description: "Bu sabah kredi kartımdan 2 kez 450 TL çekim yapıldığını fark ettim. Fazla çekilen tutarın ivedilikle iadesini rica ediyorum.",
  status: "open",
  priority: "high",
  ticket_type: "incident",
  channel: "call_center",
  requester: customer1,
  assignee: agent1,
  tags: "fatura, iade, call-ai-analyzed",
  ai_summary: "Müşteri sabah saatlerinde mükerrer 450 TL çekildiğini belirtti. Temsilci banka referans kodunu alıp muhasebe departmanına iade emri girdi.",
  ai_sentiment: "negative",
  ai_suggested_action: "Finans onayının ardından 'Fatura İadesi Onayı' makrosunu uygulayarak bileti kapatın."
)

t1.ticket_comments.create!(
  user: customer1,
  body: "Bu sabah kart hareketlerimde 2 ayrı çekim gördüm. Lütfen acil inceleyin.",
  is_internal: false,
  comment_type: "message"
)

t1.ticket_comments.create!(
  user: agent1,
  body: "Merhaba Ahmet Bey, durum banka ekstreniz üzerinden kontrol ediliyor. Kısa süre içinde bilgi vereceğim.",
  is_internal: false,
  comment_type: "message"
)

t1.ticket_comments.create!(
  user: agent1,
  body: "Muhasebe birimiyle görüşüldü, provizyon hatası kaynaklı 2. çekim tespit edildi. Gün içinde ters işlem yapılacak.",
  is_internal: true,
  comment_type: "message"
)

t2 = Ticket.create!(
  organization: org,
  subject: "API Webhook entegrasyonu 502 Bad Gateway dönüyor",
  description: "Webhook endpoint adresimize gönderilen payload'lar 502 hatası veriyor, sipariş senkronizasyonu durdu.",
  status: "pending",
  priority: "urgent",
  ticket_type: "problem",
  channel: "web",
  requester: customer2,
  assignee: agent2,
  tags: "api, webhook, devops",
  ai_summary: "Webhook alıcısında SSL handshake gecikmesi yaşanıyor. Uç nokta IP adreslerinin güvenlik duvarında beyaz listeye alınması önerildi.",
  ai_sentiment: "neutral",
  ai_suggested_action: "Müşteriden Cloudflare firewall loglarını isteyin."
)

t3 = Ticket.create!(
  organization: org,
  subject: "Yeni takım arkadaşı davet ederken SSO hatası alıyorum",
  description: "Google Workspace SAML bağlantısında 403 Forbidden yanıtı dönüyor.",
  status: "new",
  priority: "normal",
  ticket_type: "question",
  channel: "email",
  requester: customer3,
  assignee: nil,
  tags: "sso, google, onboarding",
  ai_summary: "SAML assertion parametrelerinde email mapping eksik olabilir.",
  ai_sentiment: "neutral"
)

t4 = Ticket.create!(
  organization: org,
  subject: "Yıllık plana geçişte indirim kuponu tanımlanması",
  description: "Aylık paketten yıllık Enterprise pakete geçmek istiyoruz. Satış ekibinin belirttiği %25 indirim kuponu nasıl uygulanır?",
  status: "solved",
  priority: "low",
  ticket_type: "task",
  channel: "chat",
  requester: customer1,
  assignee: agent1,
  tags: "satis, enterprise, yillik-plan",
  ai_summary: "Müşteriye 'ANNUAL25' indirim kodu tanımlandı ve faturalandırma dönemi güncellendi.",
  ai_sentiment: "positive",
  csat_rating: 5,
  csat_comment: "Hemen yardımcı oldular, harika hizmet!"
)

# 6. Call Logs & Real-time Transcripts (Microsoft Call Center AI demo)
call1 = CallLog.create!(
  organization: org,
  ticket: t1,
  agent: agent1,
  call_sid: "acs-call-890123-abc",
  caller_number: "+90 555 123 4567",
  callee_number: "+90 850 300 4050",
  caller_name: "Ahmet Kaya (TechCorp CEO)",
  direction: "inbound",
  status: "completed",
  duration_seconds: 194,
  started_at: 35.minutes.ago,
  ended_at: 31.minutes.ago,
  sentiment: "negative",
  detected_intent: "Fatura Mükerrer Tahsilat İtirazı",
  ai_summary: "Müşteri ekstresinde 2 defa 450 TL tahsilat yapıldığını iletti. Temsilci provizyon referansını alarak onaylı iade sürecini başlattı.",
  ai_action_items: "1. Muhasebeye #REF-4491 iadesi bildirildi.\n2. Kart ekstresi düzeltilince müşteriye bildirim atılacak."
)

CallTranscript.create!(call_log: call1, speaker: "ai_bot", content: "Acme Global Destek Hattına hoş geldiniz. Ben yapay zeka asistanınız. Lütfen yapmak istediğiniz işlemi kısaca belirtin.", offset_ms: 1000)
CallTranscript.create!(call_log: call1, speaker: "customer", content: "Merhaba, hesabımdan mükerrer çekim yapılmış bu sabah, kartımdan 2 defa para kesildi, acil bir yetkiliyle görüşmek istiyorum.", offset_ms: 6000)
CallTranscript.create!(call_log: call1, speaker: "ai_bot", content: "Fatura ve tahsilat itirazınız için sizi hemen yetkili finans temsilcimize aktarıyorum, lütfen hatta kalın.", offset_ms: 12000)
CallTranscript.create!(call_log: call1, speaker: "agent", content: "Merhabalar Ahmet Bey, ben Can. İtirazınızı gördüm, ekstrenizi hemen inceliyorum.", offset_ms: 18000)
CallTranscript.create!(call_log: call1, speaker: "customer", content: "Teşekkürler Can Bey, sabah 09:12 ve 09:14'te iki ayrı 450 TL çekilmiş görünüyor.", offset_ms: 24000)
CallTranscript.create!(call_log: call1, speaker: "agent", content: "Kayıtları kontrol ettim, teknik bir provizyon tekrarı oluşmuş. Fazla olan 450 TL'nin iadesini hemen sisteme girdim, gün içerisinde hesabınıza yansıyacaktır.", offset_ms: 32000)
CallTranscript.create!(call_log: call1, speaker: "customer", content: "Çok hızlı çözdünüz, çok memnun kaldım Can Bey, iyi çalışmalar.", offset_ms: 40000)

puts "Seeding completed successfully!"
