# 🎙️ OmniVoice AI — Autonomous Call Center & Voice CRM Platform

> **Next-Generation Customer Support Ecosystem:** Real-time conversational AI phone support, automated sentiment analysis, instant ticket triage, and automated resolution callbacks powered by **Ruby on Rails**, **Azure OpenAI GPT-4o**, **Azure Speech Services**, and **React Native (Expo SDK 58)**.

---

## 🌟 Overview

**OmniVoice AI** is a full-featured customer support and call center platform inspired by Zendesk, Freshdesk, and modern AI voice agents. It bridges traditional omnichannel ticketing with cutting-edge real-time voice interactions:

1. **Hands-free Mobile Calling:** Customers talk naturally with **Selin (Autonomous AI Support Agent)** via their smartphone, just like talking to a real call center representative.
2. **Real-time Voice-to-Voice Pipeline:**
   - **Voice Activity Detection (VAD):** Native decibel metering captures speech start and natural pauses in real time.
   - **In-Memory Audio Transcoding:** In-memory FFmpeg processing converts mobile audio into 16kHz mono PCM WAV in <15ms.
   - **Azure Cognitive Speech STT:** Fast, high-accuracy Turkish speech-to-text recognition.
   - **Azure OpenAI GPT-4o:** Context-aware, empathetic customer dialogue, sentiment scoring, and automated ticket generation.
   - **Text-to-Speech (TTS):** Natural conversational voice feedback.
3. **Agent & Admin Dashboard:**
   - Real-time ticket management with priority triage and sentiment flags (Angry, Frustrated, Neutral, Satisfied).
   - Live call center monitoring & incoming call simulations.
   - **One-Click "Solve & Call Back":** When an agent or AI resolves an issue, the system automatically triggers an outbound call to the customer's phone/mobile app, speaking the solution directly to them.

---

## 🏗️ System Architecture

```text
 ┌──────────────────────┐
 │ Mobile App (Expo 58) │ ── (Microphone Audio / VAD) ──┐
 └──────────────────────┘                                │
            ▲                                            ▼
            │ (TTS Speech)                 ┌──────────────────────────┐
            │                              │ Rails 7 Backend (Puma)   │
            └───────────────────────────── │  - Auth & Organizations  │
                                           │  - Ticket & Call Logs    │
                                           └──────────────────────────┘
                                                │        │        │
                     ┌──────────────────────────┘        │        └──────────────────────────┐
                     ▼                                   ▼                                   ▼
        ┌─────────────────────────┐         ┌─────────────────────────┐         ┌─────────────────────────┐
        │   static-ffmpeg (WAV)   │         │ Azure Speech (STT/TTS)  │         │  Azure OpenAI (GPT-4o)  │
        │ Fast 16kHz Mono Stream  │         │  Turkish Neural Voice   │         │ Intent / Sentiment / Bot│
        └─────────────────────────┘         └─────────────────────────┘         └─────────────────────────┘
```

---

## 🚀 Key Features

- **Hands-free AI Dialogue:** No keyboard typing required. The app listens, detects when the customer finishes their sentence, analyzes the request, and speaks the reply.
- **Automated Ticket Creation:** Understands complex customer complaints, extracts user intent, sets ticket priority (low/normal/high/urgent), and produces concise summaries.
- **Live Incoming Resolution Calling:** When a ticket status transitions to `solved`, the platform initiates an automated outbound call to notify the customer about the resolution.
- **Expo SDK 58 Architecture:** Built with the latest `expo-audio`, modern file system streams, and React 19.
- **Enterprise-Ready Rails 7 Architecture:** Multi-tenant support with organizations, users, role-based access, and RESTful API endpoints.

---

## 🛠️ Tech Stack

- **Backend:** Ruby 3.3, Ruby on Rails 7.2, Puma
- **AI & Speech:**
  - Microsoft Azure OpenAI Service (`gpt-4o`)
  - Microsoft Azure Cognitive Services Speech (Turkish `tr-TR`)
  - `static-ffmpeg` (In-memory audio pipeline)
- **Telephony & Realtime Outbound:**
  - Azure Communication Services (ACS) / Twilio Voice
- **Mobile Client:**
  - React Native, Expo SDK 58
  - `expo-audio`, `expo-speech`, `expo-file-system`
  - React 19.3.0, React Native 0.88.0

---

## ⚙️ Quick Start

### 1. Prerequisites
- Ruby 3.3+ & Bundler
- Node.js 18+ & npm
- FFmpeg (or Python `static-ffmpeg`)
- Microsoft Azure Cognitive Services & OpenAI credentials

### 2. Backend Setup
```bash
# Clone the repository
git clone https://github.com/EmreKaanSensoy/OmniVoice-AI.git
cd OmniVoice-AI

# Install Ruby dependencies
bundle install

# Setup database
bin/rails db:prepare db:seed

# Copy environment template & add your Azure keys
cp .env.example .env

# Start Rails server
bin/rails server -b 0.0.0.0 -p 3000
```

### 3. Mobile Setup
```bash
cd mobile

# Install dependencies (SDK 58 compatible)
npm install

# Start Metro Bundler
npx expo start -c
```
Scan the QR code with **Expo Go (SDK 58)** on iOS or Android.

---

## 🔒 Security & Privacy
- Sensitive keys (`.env`, private configs) are strictly excluded from version control.
- In-memory audio processing ensures ephemeral audio handling without persistent local recordings.

---

## 📄 License
MIT License. Developed with pride by [Emre Kaan Şensoy](https://github.com/EmreKaanSensoy).
