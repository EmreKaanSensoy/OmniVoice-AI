class Organization < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_many :call_logs, dependent: :destroy
  has_many :knowledge_articles, dependent: :destroy
  has_many :macros, dependent: :destroy

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: { case_sensitive: false }

  serialize :settings, coder: JSON

  def phone_number_formatted
    phone_number.presence || "+90 850 300 4050"
  end

  def ivr_greeting
    (settings || {})["ivr_greeting"].presence || "Acme Destek Hattına hoş geldiniz. Ben sesli yapay zeka asistanınızım. Size nasıl yardımcı olabilirim, sorununuz nedir?"
  end
end
