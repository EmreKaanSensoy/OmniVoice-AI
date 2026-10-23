import React, { useState, useEffect, useRef } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
  Animated,
  StatusBar,
  Modal,
  Alert,
  Vibration,
  Platform,
  Dimensions
} from 'react-native';
import * as Speech from 'expo-speech';
import {
  useAudioRecorder,
  useAudioRecorderState,
  RecordingPresets,
  requestRecordingPermissionsAsync,
  setAudioModeAsync
} from 'expo-audio';
import { File } from 'expo-file-system';
import * as FileSystemLegacy from 'expo-file-system/legacy';

const { width } = Dimensions.get('window');

// Local Wi-Fi IP of the Rails Server
const DEFAULT_API_URL = 'http://192.168.1.105:3000';

// High quality audio recording with native decibel metering explicitly enabled for VAD
const RECORDING_OPTIONS = {
  ...RecordingPresets.HIGH_QUALITY,
  isMeteringEnabled: true,
};

// Robust Base64 reader for Expo SDK 57 (3 layered fallbacks)
const readAudioAsBase64 = async (uri) => {
  if (!uri) throw new Error('Ses dosyası URI bulunamadı');

  // Metot 1: expo-file-system/legacy (Doğrudan Android native okuma)
  try {
    if (FileSystemLegacy && typeof FileSystemLegacy.readAsStringAsync === 'function') {
      const b64 = await FileSystemLegacy.readAsStringAsync(uri, {
        encoding: FileSystemLegacy.EncodingType?.Base64 || 'base64',
      });
      if (b64 && b64.length > 50) return b64;
    }
  } catch (err1) {
    console.log('FileSystemLegacy fallback notice:', err1?.message);
  }

  // Metot 2: Modern expo-file-system File API (Expo SDK 54+)
  try {
    const fileObj = new File(uri);
    if (fileObj && typeof fileObj.base64 === 'function') {
      const b64 = await fileObj.base64();
      if (b64 && b64.length > 50) return b64;
    }
  } catch (err2) {
    console.log('File.base64() fallback notice:', err2?.message);
  }

  // Metot 3: Web-standard FileReader via fetch blob
  try {
    const response = await fetch(uri);
    const blob = await response.blob();
    const b64 = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        const result = reader.result;
        if (typeof result === 'string') {
          resolve(result.replace(/^data:.*?;base64,/, ''));
        } else {
          reject(new Error('FileReader okuyamadı'));
        }
      };
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
    if (b64 && b64.length > 50) return b64;
  } catch (err3) {
    console.log('Blob FileReader fallback notice:', err3?.message);
  }

  throw new Error('Ses dosyası Base64 formatına okunamadı');
};

export default function App() {
  const [apiUrl, setApiUrl] = useState(DEFAULT_API_URL);
  const [activeTab, setActiveTab] = useState('call'); // 'call' | 'tickets'
  const [customerName, setCustomerName] = useState('Emre Kaan');
  const [customerPhone, setCustomerPhone] = useState('+90 554 720 0828');

  // Unified Call Modal State (Single Modal to prevent Android dismiss bugs)
  const [callModalVisible, setCallModalVisible] = useState(false);
  const [callView, setCallView] = useState('idle'); // 'incoming_ringing' | 'in_call'
  const [callStatus, setCallStatus] = useState('idle'); // 'dialing' | 'speaking' | 'listening' | 'thinking'
  const [callDuration, setCallDuration] = useState(0);
  const [messages, setMessages] = useState([]);
  const [activeTicket, setActiveTicket] = useState(null);
  const [micActivityText, setMicActivityText] = useState('Sizi dinliyor...');
  const [incomingCallData, setIncomingCallData] = useState(null);

  // Tickets List State
  const [tickets, setTickets] = useState([]);
  const [loadingTickets, setLoadingTickets] = useState(false);
  const [showSettings, setShowSettings] = useState(false);

  // Modern Expo-Audio Recorder Hook (Expo SDK 57 native compatible with active decibel metering)
  const recorder = useAudioRecorder(RECORDING_OPTIONS);
  const recorderState = useAudioRecorderState(recorder, 80);

  // Silence Detection & Audio Refs (timestamp based for 100% stability)
  const userSpokeRef = useRef(false);
  const lastSpeechTimeRef = useRef(0);
  const firstSpeechTimeRef = useRef(0);
  const isSendingRef = useRef(false);
  const ttsTimeoutRef = useRef(null);
  const messagesScrollRef = useRef(null);
  const messagesRef = useRef([]);
  const lastHandledCallIdRef = useRef('');
  const activeCallRef = useRef(false);
  const callStatusRef = useRef(callStatus);

  // Keep refs synced
  useEffect(() => {
    callStatusRef.current = callStatus;
  }, [callStatus]);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

  useEffect(() => {
    activeCallRef.current = callModalVisible;
  }, [callModalVisible]);

  // Animations
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const wave1 = useRef(new Animated.Value(14)).current;
  const wave2 = useRef(new Animated.Value(28)).current;
  const wave3 = useRef(new Animated.Value(20)).current;
  const wave4 = useRef(new Animated.Value(34)).current;
  const wave5 = useRef(new Animated.Value(18)).current;

  // Pulsing Avatar Animation
  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.12,
          duration: 1200,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 1200,
          useNativeDriver: true,
        }),
      ])
    ).start();
  }, []);

  // Equalizer loop when Selin speaks
  useEffect(() => {
    if (callStatus === 'speaking') {
      const loop = Animated.loop(
        Animated.parallel([
          Animated.sequence([
            Animated.timing(wave1, { toValue: 46, duration: 380, useNativeDriver: false }),
            Animated.timing(wave1, { toValue: 12, duration: 380, useNativeDriver: false }),
          ]),
          Animated.sequence([
            Animated.timing(wave2, { toValue: 62, duration: 310, useNativeDriver: false }),
            Animated.timing(wave2, { toValue: 18, duration: 310, useNativeDriver: false }),
          ]),
          Animated.sequence([
            Animated.timing(wave3, { toValue: 52, duration: 440, useNativeDriver: false }),
            Animated.timing(wave3, { toValue: 14, duration: 440, useNativeDriver: false }),
          ]),
          Animated.sequence([
            Animated.timing(wave4, { toValue: 66, duration: 290, useNativeDriver: false }),
            Animated.timing(wave4, { toValue: 20, duration: 290, useNativeDriver: false }),
          ]),
          Animated.sequence([
            Animated.timing(wave5, { toValue: 42, duration: 360, useNativeDriver: false }),
            Animated.timing(wave5, { toValue: 10, duration: 360, useNativeDriver: false }),
          ]),
        ])
      );
      loop.start();
      return () => loop.stop();
    }
  }, [callStatus]);

  // Real-time Voice Activity Detection (VAD) & Wave Animation from Microphone Metering
  useEffect(() => {
    if (!recorderState.isRecording || callStatus !== 'listening' || isSendingRef.current) return;
    const db = recorderState.metering != null ? recorderState.metering : -160;

    // Animate equalizer bars in real time based on voice volume
    // db ranges from ~ -60 (silence) to ~ -10 (loud speech)
    const normalized = Math.max(0, Math.min(1, (db + 58) / 45));
    const level = 12 + normalized * 50;
    wave1.setValue(level * 0.75);
    wave2.setValue(level * 1.0);
    wave3.setValue(level * 1.15);
    wave4.setValue(level * 0.95);
    wave5.setValue(level * 0.7);

    const now = Date.now();

    // -47 dB konuşma algılama eşiği (fısıltı veya normal ses anında yakalar)
    if (db > -47) {
      if (!userSpokeRef.current) {
        userSpokeRef.current = true;
        firstSpeechTimeRef.current = now;
      }
      lastSpeechTimeRef.current = now;
      setMicActivityText(`🎙️ Konuşuyorsunuz (${Math.round(db)} dB)...`);
    } else if (userSpokeRef.current) {
      const silenceDuration = now - lastSpeechTimeRef.current;
      const totalDuration = now - firstSpeechTimeRef.current;

      // 20 saniye kesintisiz konuşulduysa veya 1.35 saniye sessizlik olduysa otomatik gönder!
      if (totalDuration >= 20000 || silenceDuration >= 1350) {
        setMicActivityText('⏳ Cümleniz alındı, Selin yanıtlıyor...');
        finishAndSendVoiceRecording();
      } else {
        setMicActivityText(`🎙️ Dinleniyor... (${(silenceDuration / 1000).toFixed(1)}s)`);
      }
    }
  }, [recorderState.metering, recorderState.isRecording, callStatus]);

  // Call Duration Timer
  useEffect(() => {
    let interval = null;
    if (callModalVisible && callView === 'in_call' && callStatus !== 'dialing') {
      interval = setInterval(() => {
        setCallDuration((prev) => prev + 1);
      }, 1000);
    } else {
      setCallDuration(0);
    }
    return () => clearInterval(interval);
  }, [callModalVisible, callView, callStatus]);

  const formatTime = (secs) => {
    const mins = Math.floor(secs / 60);
    const remainingSecs = secs % 60;
    return `${mins < 10 ? '0' : ''}${mins}:${remainingSecs < 10 ? '0' : ''}${remainingSecs}`;
  };

  // --------------------------------------------------------------------------
  // 1. INCOMING RESOLUTION CALL POLLING (ADMIN ÇÖZÜNCE AI GERİ ARIYOR)
  // --------------------------------------------------------------------------
  useEffect(() => {
    const checkInterval = setInterval(async () => {
      // Aktif bir çağrı varken arama kontrolü yapma
      if (activeCallRef.current) return;

      try {
        const queryUrl = `${apiUrl}/api/v1/mobile/check_call?handled_call_id=${encodeURIComponent(lastHandledCallIdRef.current)}`;
        const response = await fetch(queryUrl, {
          method: 'GET',
          headers: { 'Accept': 'application/json' }
        });

        if (response.ok) {
          const data = await response.json();
          if (data.has_incoming_call && data.call) {
            const callObj = data.call;
            if (callObj.id !== lastHandledCallIdRef.current && !activeCallRef.current) {
              setIncomingCallData(callObj);
              setCallView('incoming_ringing');
              setCallModalVisible(true);
              Vibration.vibrate([700, 700, 700, 700], true);
            }
          }
        }
      } catch (err) {
        // Silently ignore polling network errors
      }
    }, 2500);

    return () => clearInterval(checkInterval);
  }, [apiUrl]);

  // --------------------------------------------------------------------------
  // 2. ANSWERING & REJECTING INCOMING RESOLUTION CALLS
  // --------------------------------------------------------------------------
  const answerIncomingResolutionCall = async () => {
    Vibration.cancel();
    const callData = incomingCallData;

    if (callData?.id) {
      lastHandledCallIdRef.current = callData.id;
    }

    // Modal kapanmadan aynı pencere içinde in_call moduna geç (Android bug'ını önler)
    setCallView('in_call');
    setCallStatus('speaking');
    setCallDuration(0);
    setActiveTicket({
      id: callData?.ticket_id,
      number: callData?.ticket_number,
      subject: callData?.ticket_subject,
    });

    // Sunucuya bildir ki arama durumu 'answered' olsun ve ASLA TEKRAR ÇALMASIN!
    try {
      fetch(`${apiUrl}/api/v1/mobile/answer_call`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          call_id: callData?.call_id,
          ticket_id: callData?.ticket_id,
        })
      });
    } catch (e) {}

    const resolutionSpeech = callData?.speech_text ||
      callData?.spoken_message ||
      `İyi günler Sayın ${customerName}, ben müşteri temsilciniz Selin. ${callData?.ticket_number || ''} numaralı destek talebiniz uzman ekibimiz tarafından çözüme kavuşturulmuştur. Bu konuyla ilgili aklınıza takılan bir soru var mı?`;

    setMessages([{ role: 'assistant', content: resolutionSpeech }]);

    // Selin çözümü seslendirir, konuşması bitince OTOMATİK mikrofon açılır!
    speakAgent(resolutionSpeech);
  };

  const rejectIncomingResolutionCall = async () => {
    Vibration.cancel();
    Speech.stop();
    const callData = incomingCallData;

    if (callData?.id) {
      lastHandledCallIdRef.current = callData.id;
    }

    setCallModalVisible(false);
    setCallView('idle');
    setIncomingCallData(null);

    try {
      fetch(`${apiUrl}/api/v1/mobile/end_call`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          call_id: callData?.call_id,
          ticket_id: callData?.ticket_id,
        })
      });
    } catch (e) {}
  };

  // --------------------------------------------------------------------------
  // 3. OUTBOUND CALL TO SELIN (MÜŞTERİ HİZMETLERİNİ ARA)
  // --------------------------------------------------------------------------
  const startOutboundCall = async () => {
    try {
      // 1. Microphone Permission
      const perm = await requestRecordingPermissionsAsync();
      if (!perm.granted) {
        Alert.alert('Mikrofon İzni Gerekli', 'Yapay zeka ile doğrudan sesli konuşabilmek için mikrofon izni vermelisiniz.');
        return;
      }

      // 2. Audio Mode setup
      try {
        await setAudioModeAsync({
          playsInSilentMode: true,
          allowsRecording: true,
        });
      } catch (e) {}

      // 3. Open Single Unified Modal in in_call mode
      setIncomingCallData(null);
      setCallView('in_call');
      setCallModalVisible(true);
      setCallStatus('dialing');
      setMessages([]);
      setActiveTicket(null);
      Vibration.vibrate([100, 150, 100]);

      // Selin greets after short dialing tone
      setTimeout(async () => {
        try {
          setCallStatus('thinking');
          const res = await fetch(`${apiUrl}/api/v1/mobile/conversational_call`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              call_action: 'start',
              customer_name: customerName,
              customer_phone: customerPhone
            })
          });

          if (res.ok) {
            const data = await res.json();
            const initialReply = data.ai_reply || `İyi günler ${customerName} Bey, Acme Destek Hattına hoş geldiniz. Ben müşteri temsilciniz Selin. Size bugün nasıl yardımcı olabilirim?`;
            setMessages([{ role: 'assistant', content: initialReply }]);
            speakAgent(initialReply);
          } else {
            fallbackStart();
          }
        } catch (e) {
          fallbackStart();
        }
      }, 1200);
    } catch (err) {
      console.log('Error starting outbound call:', err);
      fallbackStart();
    }
  };

  const fallbackStart = () => {
    const text = `İyi günler ${customerName} Bey, Acme Destek Hattına hoş geldiniz. Ben müşteri temsilciniz Selin. Size bugün nasıl yardımcı olabilirim?`;
    setMessages([{ role: 'assistant', content: text }]);
    speakAgent(text);
  };

  // --------------------------------------------------------------------------
  // 4. TTS (SELİN'İN TÜRKÇE KONUŞMASI) & BİTİNCE OTOMATİK MİKROFONA GEÇİŞ
  // --------------------------------------------------------------------------
  const speakAgent = (text) => {
    setCallStatus('speaking');
    Speech.stop();
    if (ttsTimeoutRef.current) clearTimeout(ttsTimeoutRef.current);

    // Failsafe timeout in case TTS engine on Android does not fire onDone
    const estimatedDuration = Math.max(3000, Math.min(22000, (text?.length || 50) * 85 + 2500));
    ttsTimeoutRef.current = setTimeout(() => {
      if (activeCallRef.current && callStatus === 'speaking') {
        startHandsFreeListening();
      }
    }, estimatedDuration);

    Speech.speak(text, {
      language: 'tr-TR',
      pitch: 1.05,
      rate: 0.98,
      onDone: () => {
        if (ttsTimeoutRef.current) clearTimeout(ttsTimeoutRef.current);
        // SELİN CÜMLESİNİ BİTİRDİĞİ AN OTOMATİK OLARAK MİKROFONDAN DİNLEMEYE BAŞLA!
        startHandsFreeListening();
      },
      onError: () => {
        if (ttsTimeoutRef.current) clearTimeout(ttsTimeoutRef.current);
        startHandsFreeListening();
      }
    });
  };

  // --------------------------------------------------------------------------
  // 5. DIRECT MICROPHONE LISTENING (HANDS-FREE SES & SESSİZLİK TESPİTİ)
  // --------------------------------------------------------------------------
  const startHandsFreeListening = async () => {
    try {
      Speech.stop();
      if (ttsTimeoutRef.current) {
        clearTimeout(ttsTimeoutRef.current);
        ttsTimeoutRef.current = null;
      }

      userSpokeRef.current = false;
      lastSpeechTimeRef.current = 0;
      firstSpeechTimeRef.current = 0;
      isSendingRef.current = false;
      setCallStatus('listening');
      setMicActivityText('🎙️ Sizi dinliyor... Konuşabilirsiniz');

      try {
        if (recorder.isRecording) {
          await recorder.stop();
        }
      } catch (e) {}

      try {
        await recorder.prepareToRecordAsync(RECORDING_OPTIONS);
      } catch (prepErr) {
        // Safe to proceed if already prepared
      }

      recorder.record();
    } catch (err) {
      console.log('Error starting hands-free recording:', err);
    }
  };

  // Cümle Bittiğinde Ses Dosyasını Durdurup Sunucuya Gönderme (Azure STT + GPT-4o)
  const finishAndSendVoiceRecording = async () => {
    if (isSendingRef.current) return;
    isSendingRef.current = true;

    setCallStatus('thinking');
    setMicActivityText('⏳ Sesiniz işleniyor...');

    try {
      // 1. Kayıt durdurulmadan önce ve sonra dosya URI'sini güvenle al
      let uri = recorder.uri || recorderState?.url || recorder.getStatus?.()?.url;

      try {
        if (recorder.isRecording) {
          const stopStatus = await recorder.stop();
          if (stopStatus?.url) uri = stopStatus.url;
        }
      } catch (stopErr) {
        console.log('Stop recorder notice:', stopErr?.message);
      }

      if (!uri) uri = recorder.uri || recorderState?.url || recorder.getStatus?.()?.url;

      if (!uri) {
        console.log('No audio URI found!');
        setMicActivityText('⚠️ Ses dosyası bulunamadı');
        setTimeout(() => startHandsFreeListening(), 1500);
        return;
      }

      // 2. Ses dosyasını 3 katmanlı fallback ile Base64 formatına çevir
      setMicActivityText('🎙️ Ses metne dökülüyor (Azure STT)...');
      let base64Audio = null;
      try {
        base64Audio = await readAudioAsBase64(uri);
      } catch (readErr) {
        console.log('Failed to read base64 audio:', readErr);
        setMicActivityText('⚠️ ' + (readErr?.message || 'Ses okunamadı'));
        setTimeout(() => startHandsFreeListening(), 2500);
        return;
      }

      if (!base64Audio || base64Audio.length < 50) {
        setMicActivityText('⚠️ Ses verisi boş');
        setTimeout(() => startHandsFreeListening(), 1500);
        return;
      }

      setMicActivityText('🤖 Selin yanıt hazırlıyor...');

      // 3. Rails backend'e JSON formatında Base64 gönder (Azure STT -> GPT-4o)
      const res = await fetch(`${apiUrl}/api/v1/mobile/conversational_audio`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({
          audio_base64: base64Audio,
          customer_name: customerName,
          customer_phone: customerPhone,
          messages: messagesRef.current,
          duration_seconds: callDuration,
          existing_ticket_id: activeTicket?.id || null,
        })
      });

      if (res.ok) {
        const data = await res.json();

        if (data.recognized && data.user_transcript) {
          // Azure Speech STT ile kullanıcının sesi Türkçe metne dönüştürüldü!
          const newHistory = [
            ...messagesRef.current,
            { role: 'user', content: data.user_transcript },
            { role: 'assistant', content: data.ai_reply }
          ];
          setMessages(newHistory);

          if (data.ticket_created && data.ticket) {
            setActiveTicket(data.ticket);
            Vibration.vibrate([100, 100, 200]);
          }

          // Selin yanıtını sesli okur, bitince OTOMATİK olarak tekrar mikrofona döner!
          speakAgent(data.ai_reply);
        } else {
          // Ses çok kısa veya anlaşılamadı, Selin kibarca tekrar sorar
          speakAgent(data.message || "Sesinizi tam alamadım, lütfen tekrar söyleyebilir misiniz?");
        }
      } else {
        const errText = await res.text();
        console.log('Server error:', res.status, errText);
        setMicActivityText(`⚠️ Sunucu Hatası (${res.status})`);
        setTimeout(() => startHandsFreeListening(), 2500);
      }
    } catch (err) {
      console.log('Error uploading audio:', err);
      setMicActivityText('⚠️ Bağlantı hatası: ' + err.message);
      setTimeout(() => startHandsFreeListening(), 2500);
    } finally {
      isSendingRef.current = false;
    }
  };

  // Aramayı Kapat
  const endCall = async () => {
    Speech.stop();
    isSendingRef.current = false;
    if (ttsTimeoutRef.current) {
      clearTimeout(ttsTimeoutRef.current);
      ttsTimeoutRef.current = null;
    }
    userSpokeRef.current = false;
    lastSpeechTimeRef.current = 0;
    firstSpeechTimeRef.current = 0;

    if (recorder.isRecording) {
      try {
        await recorder.stop();
      } catch (e) {}
    }

    setCallModalVisible(false);
    setCallView('idle');
    setCallStatus('idle');
    Vibration.vibrate(200);

    // Notify backend
    try {
      fetch(`${apiUrl}/api/v1/mobile/end_call`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          call_id: incomingCallData?.call_id,
          ticket_id: activeTicket?.id || incomingCallData?.ticket_id
        })
      });
    } catch (e) {}

    if (activeTicket) {
      Alert.alert(
        'Görüşme Tamamlandı 📞',
        `Görüşmeniz biletlendirildi.\n\nBilet: ${activeTicket.number || activeTicket.id}\nKonu: ${activeTicket.subject || ''}\n\nEkibimiz inceleyip çözdüğünde bu uygulama üzerinden AI geri araması yapılacaktır.`,
        [{ text: 'Tamam' }]
      );
    }
  };

  // --------------------------------------------------------------------------
  // 6. BİLETLERİ LİSTELEME
  // --------------------------------------------------------------------------
  const fetchTickets = async () => {
    setLoadingTickets(true);
    try {
      const res = await fetch(`${apiUrl}/api/v1/mobile/tickets`);
      if (res.ok) {
        const data = await res.json();
        setTickets(data.tickets || []);
      }
    } catch (err) {}
    finally {
      setLoadingTickets(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'tickets') {
      fetchTickets();
    }
  }, [activeTab]);

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#0b0f19" />

      {/* HEADER */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <View style={styles.logoBadge}>
            <Text style={styles.logoText}>ACME</Text>
          </View>
          <View>
            <Text style={styles.appName}>Müşteri Hizmetleri</Text>
            <View style={styles.statusRow}>
              <View style={styles.statusDotLive} />
              <Text style={styles.statusSubText}>Canlı Sesli Santral Çevrimiçi</Text>
            </View>
          </View>
        </View>
        <TouchableOpacity style={styles.gearButton} onPress={() => setShowSettings(true)}>
          <Text style={styles.gearIcon}>⚙️</Text>
        </TouchableOpacity>
      </View>

      {/* TAB SELECTOR */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tabButton, activeTab === 'call' && styles.activeTabButton]}
          onPress={() => setActiveTab('call')}
        >
          <Text style={[styles.tabText, activeTab === 'call' && styles.activeTabText]}>
            📞 Canlı Telefon Görüşmesi
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tabButton, activeTab === 'tickets' && styles.activeTabButton]}
          onPress={() => setActiveTab('tickets')}
        >
          <Text style={[styles.tabText, activeTab === 'tickets' && styles.activeTabText]}>
            🎫 Biletlerim ({tickets.length})
          </Text>
        </TouchableOpacity>
      </View>

      {/* -------------------------------------------------------------------- */}
      {/* TAB 1: TELEFON GÖRÜŞMESİ ANA EKRANI                                 */}
      {/* -------------------------------------------------------------------- */}
      {activeTab === 'call' && (
        <ScrollView contentContainerStyle={styles.mainCallContent} showsVerticalScrollIndicator={false}>
          {/* Agent Profile Card */}
          <View style={styles.agentCard}>
            <Animated.View style={[styles.agentAvatarContainer, { transform: [{ scale: pulseAnim }] }]}>
              <Text style={styles.agentAvatarEmoji}>👩‍💼</Text>
              <View style={styles.onlineBadge}>
                <View style={styles.onlineDot} />
              </View>
            </Animated.View>
            <Text style={styles.agentName}>Selin</Text>
            <Text style={styles.agentTitle}>Kıdemli AI Müşteri Temsilcisi</Text>
            <Text style={styles.agentDescription}>
              Doğrudan telefon görüşmesi yapar gibi konuşun! Klavyeye gerek yok. Selin konuşmanızı dinler ve cümleniz bittiğinde anında sesli yanıt verir.
            </Text>

            <View style={styles.featurePillsRow}>
              <View style={styles.featurePill}>
                <Text style={styles.featurePillText}>🎙️ Otomatik Konuşma Algılama</Text>
              </View>
              <View style={styles.featurePill}>
                <Text style={styles.featurePillText}>⚡ Azure Speech + GPT-4o</Text>
              </View>
            </View>
          </View>

          {/* Big Glowing Call Button */}
          <TouchableOpacity style={styles.startCallButton} onPress={startOutboundCall} activeOpacity={0.85}>
            <View style={styles.callIconBubble}>
              <Text style={styles.callBigEmoji}>📞</Text>
            </View>
            <View style={styles.callButtonTextCol}>
              <Text style={styles.startCallTitle}>Müşteri Hizmetlerini Ara</Text>
              <Text style={styles.startCallSub}>Doğrudan eller serbest görüşme başlat</Text>
            </View>
          </TouchableOpacity>

          {/* Test Calling Scenario Cards */}
          <View style={styles.scenariosSection}>
            <Text style={styles.sectionTitle}>💡 Selin'e Sorabileceğiniz Örnek Konular</Text>
            <Text style={styles.sectionSubtitle}>
              Aramayı başlattığınızda Selin'e doğrudan sesinizle aktarabilirsiniz:
            </Text>

            <View style={styles.scenariosGrid}>
              <View style={styles.scenarioCard}>
                <Text style={styles.scenarioEmoji}>💳</Text>
                <Text style={styles.scenarioHeading}>Hatalı Çekim & İade</Text>
                <Text style={styles.scenarioSnippet}>"Kartımdan siparişim için mükerrer çekim yapılmış..."</Text>
              </View>

              <View style={styles.scenarioCard}>
                <Text style={styles.scenarioEmoji}>📦</Text>
                <Text style={styles.scenarioHeading}>Kargo Durumu</Text>
                <Text style={styles.scenarioSnippet}>"Dün verdiğim siparişim kargoya verildi mi?.."</Text>
              </View>

              <View style={styles.scenarioCard}>
                <Text style={styles.scenarioEmoji}>🌐</Text>
                <Text style={styles.scenarioHeading}>Teknik Arıza</Text>
                <Text style={styles.scenarioSnippet}>"Ev internetim kesildi, modemde kırmızı ışık yanıyor..."</Text>
              </View>
            </View>
          </View>

          {/* User Info Bar */}
          <View style={styles.callerInfoBox}>
            <Text style={styles.callerInfoLabel}>👤 Kayıtlı Abone:</Text>
            <Text style={styles.callerInfoValue}>{customerName} ({customerPhone})</Text>
          </View>
        </ScrollView>
      )}

      {/* -------------------------------------------------------------------- */}
      {/* TAB 2: BİLETLERİM LİSTESİ                                            */}
      {/* -------------------------------------------------------------------- */}
      {activeTab === 'tickets' && (
        <ScrollView contentContainerStyle={styles.ticketsContent}>
          <View style={styles.ticketsHeaderRow}>
            <Text style={styles.ticketsTitle}>Açılan Destek Talepleriniz</Text>
            <TouchableOpacity onPress={fetchTickets} style={styles.refreshBtn}>
              <Text style={styles.refreshText}>Yenile 🔄</Text>
            </TouchableOpacity>
          </View>

          {loadingTickets ? (
            <ActivityIndicator size="large" color="#6366f1" style={{ marginTop: 40 }} />
          ) : tickets.length === 0 ? (
            <View style={styles.emptyTickets}>
              <Text style={styles.emptyEmoji}>📭</Text>
              <Text style={styles.emptyTitle}>Henüz bir biletiniz yok</Text>
              <Text style={styles.emptySubtitle}>Selin ile doğrudan sesli görüşerek ilk biletinizi açabilirsiniz.</Text>
            </View>
          ) : (
            tickets.map((t) => (
              <View key={t.id} style={styles.ticketCard}>
                <View style={styles.ticketCardHeader}>
                  <Text style={styles.ticketNumber}>{t.number}</Text>
                  <View style={[styles.ticketBadge, t.status === 'solved' ? styles.badgeSolved : styles.badgeOpen]}>
                    <Text style={styles.ticketBadgeText}>{t.status_label || t.status}</Text>
                  </View>
                </View>
                <Text style={styles.ticketSubject}>{t.subject}</Text>
                {t.ai_summary ? (
                  <View style={styles.ticketSummaryBox}>
                    <Text style={styles.summaryLabel}>🤖 AI Görüşme Özeti:</Text>
                    <Text style={styles.summaryText}>{t.ai_summary}</Text>
                  </View>
                ) : null}
                {t.status === 'solved' && t.solution ? (
                  <View style={styles.solutionBox}>
                    <Text style={styles.solutionTitle}>✅ Çözüm & Bilgilendirme:</Text>
                    <Text style={styles.solutionText}>{t.solution}</Text>
                  </View>
                ) : null}
                <View style={styles.ticketFooter}>
                  <Text style={styles.ticketMeta}>Öncelik: <Text style={{ color: '#fff' }}>{t.priority?.toUpperCase()}</Text></Text>
                  <Text style={styles.ticketMeta}>{t.created_at}</Text>
                </View>
              </View>
            ))
          )}
        </ScrollView>
      )}

      {/* ==================================================================== */}
      {/* TEK VE BİRLEŞİK ÇAĞRI MODALI (HERMES / ANDROID CRASH GÜVENLİ)       */}
      {/* ==================================================================== */}
      <Modal visible={callModalVisible} animationType="slide" transparent={false}>
        <View style={styles.callModalContainer}>
          <StatusBar barStyle="light-content" backgroundColor="#050811" />

          {/* VIEW A: GELEN ARAMA EKRANI (ADMİN ÇÖZÜNCE ÇALAN EKRAN) */}
          {callView === 'incoming_ringing' && (
            <View style={styles.incomingContent}>
              <View style={styles.incomingTop}>
                <Text style={styles.incomingCompany}>ACME ÇÖZÜM MERKEZİ</Text>
                <Text style={styles.incomingSub}>Gelen AI Sesli Çözüm Çağrısı</Text>
              </View>

              <Animated.View style={[styles.incomingAvatarRing, { transform: [{ scale: pulseAnim }] }]}>
                <Text style={styles.incomingEmoji}>👩‍💼</Text>
              </Animated.View>

              <Text style={styles.callerNameText}>Selin (Acme Destek)</Text>
              <Text style={styles.ticketContextBadge}>
                {incomingCallData?.ticket_number || 'Bilet'} Çözümlendi
              </Text>

              <View style={styles.solutionPreviewCard}>
                <Text style={styles.solutionPreviewTitle}>📋 Bilet & Çözüm Detayı:</Text>
                <Text style={styles.solutionPreviewSubject}>
                  {incomingCallData?.ticket_subject || 'Talebiniz Çözümlendi'}
                </Text>
                <Text style={styles.solutionPreviewText}>
                  {incomingCallData?.solution_summary || 'Uzman ekibimiz sorununuzu inceledi ve çözdü. Detayları dinlemek için çağrıyı yanıtlayın.'}
                </Text>
              </View>

              {/* Yanıtla ve Reddet Butonları */}
              <View style={styles.incomingActionsRow}>
                <TouchableOpacity style={styles.rejectBtn} onPress={rejectIncomingResolutionCall} activeOpacity={0.8}>
                  <Text style={styles.actionBtnIcon}>✕</Text>
                  <Text style={styles.actionBtnLabel}>Reddet</Text>
                </TouchableOpacity>

                <TouchableOpacity style={styles.acceptBtn} onPress={answerIncomingResolutionCall} activeOpacity={0.8}>
                  <Text style={[styles.actionBtnIcon, { backgroundColor: '#10b981' }]}>📞</Text>
                  <Text style={styles.actionBtnLabel}>Yanıtla</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {/* VIEW B: AKTİF TELEFON GÖRÜŞMESİ (HANDS-FREE CANLI KONUŞMA) */}
          {callView === 'in_call' && (
            <View style={{ flex: 1 }}>
              {/* Top Bar */}
              <View style={styles.callTopBar}>
                <Text style={styles.callCompanyName}>ACME DESTEK MERKEZİ</Text>
                <Text style={styles.callAgentSubtitle}>
                  {incomingCallData ? 'Çözüm Bilgilendirme Görüşmesi' : 'Canlı Müşteri Temsilcisi'}
                </Text>

                {/* Call Status Badge */}
                <View style={styles.callStatusBadgeWrapper}>
                  {callStatus === 'dialing' && (
                    <View style={[styles.statePill, { backgroundColor: 'rgba(234, 179, 8, 0.2)', borderColor: '#eab308' }]}>
                      <ActivityIndicator size="small" color="#eab308" style={{ marginRight: 6 }} />
                      <Text style={[styles.statePillText, { color: '#eab308' }]}>Bağlanıyor...</Text>
                    </View>
                  )}
                  {callStatus === 'speaking' && (
                    <View style={[styles.statePill, { backgroundColor: 'rgba(16, 185, 129, 0.2)', borderColor: '#10b981' }]}>
                      <View style={[styles.statusDotLive, { backgroundColor: '#10b981' }]} />
                      <Text style={[styles.statePillText, { color: '#10b981' }]}>Selin Konuşuyor...</Text>
                    </View>
                  )}
                  {callStatus === 'listening' && (
                    <View style={[styles.statePill, { backgroundColor: 'rgba(99, 102, 241, 0.2)', borderColor: '#6366f1' }]}>
                      <View style={[styles.statusDotLive, { backgroundColor: '#6366f1' }]} />
                      <Text style={[styles.statePillText, { color: '#818cf8' }]}>🎙️ Mikrofon Açık: Konuşabilirsiniz</Text>
                    </View>
                  )}
                  {callStatus === 'thinking' && (
                    <View style={[styles.statePill, { backgroundColor: 'rgba(236, 72, 153, 0.2)', borderColor: '#ec4899' }]}>
                      <ActivityIndicator size="small" color="#ec4899" style={{ marginRight: 6 }} />
                      <Text style={[styles.statePillText, { color: '#ec4899' }]}>Selin Yanıtlıyor...</Text>
                    </View>
                  )}
                </View>

                <Text style={styles.callTimerText}>{formatTime(callDuration)}</Text>
              </View>

              {/* Center: Avatar & Equalizer */}
              <View style={styles.callAvatarSection}>
                <View style={styles.avatarGlowCircle}>
                  <Animated.View style={[styles.callAvatarCircle, { transform: [{ scale: pulseAnim }] }]}>
                    <Text style={styles.callAvatarEmoji}>👩‍💼</Text>
                  </Animated.View>
                </View>
                <Text style={styles.callAgentName}>Selin</Text>
                <Text style={styles.callAgentRole}>Acme Müşteri Temsilcisi</Text>

                {/* Dynamic Equalizer Waves */}
                <View style={styles.equalizerRow}>
                  <Animated.View style={[styles.eqBar, { height: wave1, backgroundColor: callStatus === 'speaking' ? '#10b981' : '#6366f1' }]} />
                  <Animated.View style={[styles.eqBar, { height: wave2, backgroundColor: callStatus === 'speaking' ? '#10b981' : '#818cf8' }]} />
                  <Animated.View style={[styles.eqBar, { height: wave4, backgroundColor: callStatus === 'speaking' ? '#10b981' : '#a855f7' }]} />
                  <Animated.View style={[styles.eqBar, { height: wave3, backgroundColor: callStatus === 'speaking' ? '#10b981' : '#ec4899' }]} />
                  <Animated.View style={[styles.eqBar, { height: wave5, backgroundColor: callStatus === 'speaking' ? '#10b981' : '#6366f1' }]} />
                </View>
              </View>

              {/* Active Ticket Banner */}
              {activeTicket && (
                <View style={styles.activeTicketBanner}>
                  <Text style={styles.activeTicketIcon}>📋</Text>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.activeTicketTitle}>Görüşülen Bilet: {activeTicket.number}</Text>
                    <Text style={styles.activeTicketNumber}>{activeTicket.subject}</Text>
                  </View>
                </View>
              )}

              {/* Transcript Scroll */}
              <View style={styles.transcriptContainer}>
                <ScrollView
                  ref={messagesScrollRef}
                  style={styles.transcriptScroll}
                  contentContainerStyle={{ paddingVertical: 10 }}
                  showsVerticalScrollIndicator={false}
                  onContentSizeChange={() => messagesScrollRef.current?.scrollToEnd({ animated: true })}
                >
                  {messages.map((m, idx) => (
                    <View
                      key={idx}
                      style={[
                        styles.chatBubble,
                        m.role === 'user' ? styles.userBubble : styles.agentBubble
                      ]}
                    >
                      <Text style={styles.bubbleSpeaker}>
                        {m.role === 'user' ? customerName : 'Selin'}
                      </Text>
                      <Text style={styles.bubbleContent}>{m.content}</Text>
                    </View>
                  ))}
                </ScrollView>
              </View>

              {/* Hands-Free Voice Guidance & Quick Finish Button */}
              <View style={styles.handsfreeControlCard}>
                <View style={styles.handsfreeHeaderRow}>
                  <View style={[styles.statusDotLive, { backgroundColor: callStatus === 'listening' ? '#6366f1' : '#10b981' }]} />
                  <Text style={styles.handsfreeStatusLabel}>
                    {callStatus === 'listening' ? micActivityText : callStatus === 'speaking' ? '🔊 Selin Konuşuyor...' : '⏳ Yanıt Hazırlanıyor...'}
                  </Text>
                </View>

                {callStatus === 'listening' && (
                  <TouchableOpacity
                    style={styles.forceSendBtn}
                    onPress={finishAndSendVoiceRecording}
                    activeOpacity={0.8}
                  >
                    <Text style={styles.forceSendBtnText}>✓ Cümlemi Bitirdim (Hemen Yanıtla)</Text>
                  </TouchableOpacity>
                )}
              </View>

              {/* Bottom Hangup Controls */}
              <View style={styles.callBottomControls}>
                <View style={styles.controlBtnWrapper}>
                  <TouchableOpacity style={styles.subControlBtn}>
                    <Text style={styles.subControlIcon}>🔇</Text>
                  </TouchableOpacity>
                  <Text style={styles.subControlLabel}>Sessiz</Text>
                </View>

                <TouchableOpacity style={styles.hangupButton} onPress={endCall} activeOpacity={0.85}>
                  <Text style={styles.hangupIcon}>📞</Text>
                </TouchableOpacity>

                <View style={styles.controlBtnWrapper}>
                  <TouchableOpacity style={styles.subControlBtn}>
                    <Text style={styles.subControlIcon}>🔊</Text>
                  </TouchableOpacity>
                  <Text style={styles.subControlLabel}>Hoparlör</Text>
                </View>
              </View>
            </View>
          )}
        </View>
      </Modal>

      {/* SETTINGS MODAL */}
      <Modal visible={showSettings} animationType="slide" transparent={true}>
        <View style={styles.settingsOverlay}>
          <View style={styles.settingsCard}>
            <Text style={styles.settingsTitle}>⚙️ Sunucu & Abone Ayarları</Text>

            <Text style={styles.inputLabel}>Rails Sunucu Wi-Fi IP Adresi:</Text>
            <View style={styles.settingsInputBox}>
              <Text style={styles.settingsInputText}>{apiUrl}</Text>
            </View>

            <Text style={styles.inputLabel}>Abone Adı:</Text>
            <View style={styles.settingsInputBox}>
              <Text style={styles.settingsInputText}>{customerName}</Text>
            </View>

            <Text style={styles.inputLabel}>Telefon Numarası:</Text>
            <View style={styles.settingsInputBox}>
              <Text style={styles.settingsInputText}>{customerPhone}</Text>
            </View>

            <TouchableOpacity style={styles.saveBtn} onPress={() => setShowSettings(false)}>
              <Text style={styles.saveBtnText}>Kapat</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0b0f19',
    paddingTop: Platform.OS === 'android' ? (StatusBar.currentHeight || 0) : 44,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 18,
    paddingTop: Platform.OS === 'android' ? 12 : 6,
    paddingBottom: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#1e293b',
    backgroundColor: '#0b0f19',
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  logoBadge: {
    backgroundColor: '#6366f1',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 8,
    marginRight: 12,
  },
  logoText: {
    color: '#ffffff',
    fontWeight: '900',
    fontSize: 14,
    letterSpacing: 1.5,
  },
  appName: {
    color: '#f8fafc',
    fontSize: 16,
    fontWeight: '800',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 2,
  },
  statusDotLive: {
    width: 7,
    height: 7,
    borderRadius: 3.5,
    backgroundColor: '#10b981',
    marginRight: 6,
  },
  statusSubText: {
    color: '#94a3b8',
    fontSize: 11,
    fontWeight: '600',
  },
  gearButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#1e293b',
    justifyContent: 'center',
    alignItems: 'center',
  },
  gearIcon: {
    fontSize: 16,
  },
  tabContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: '#0f172a',
    gap: 10,
  },
  tabButton: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 12,
    alignItems: 'center',
    backgroundColor: '#1e293b',
  },
  activeTabButton: {
    backgroundColor: '#6366f1',
  },
  tabText: {
    color: '#94a3b8',
    fontSize: 13,
    fontWeight: '700',
  },
  activeTabText: {
    color: '#ffffff',
  },
  mainCallContent: {
    padding: 20,
    paddingBottom: 40,
  },
  agentCard: {
    backgroundColor: '#131b2e',
    borderRadius: 24,
    padding: 22,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#1e293b',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
    elevation: 8,
  },
  agentAvatarContainer: {
    width: 90,
    height: 90,
    borderRadius: 45,
    backgroundColor: '#1e1b4b',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#6366f1',
    marginBottom: 12,
  },
  agentAvatarEmoji: {
    fontSize: 44,
  },
  onlineBadge: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: '#0b0f19',
    justifyContent: 'center',
    alignItems: 'center',
  },
  onlineDot: {
    width: 14,
    height: 14,
    borderRadius: 7,
    backgroundColor: '#10b981',
  },
  agentName: {
    color: '#ffffff',
    fontSize: 24,
    fontWeight: '800',
  },
  agentTitle: {
    color: '#818cf8',
    fontSize: 13,
    fontWeight: '600',
    marginTop: 2,
  },
  agentDescription: {
    color: '#94a3b8',
    fontSize: 13,
    textAlign: 'center',
    lineHeight: 19,
    marginTop: 10,
    paddingHorizontal: 8,
  },
  featurePillsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 8,
    marginTop: 14,
  },
  featurePill: {
    backgroundColor: 'rgba(99, 102, 241, 0.15)',
    borderColor: 'rgba(99, 102, 241, 0.4)',
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
  },
  featurePillText: {
    color: '#c7d2fe',
    fontSize: 11,
    fontWeight: '700',
  },
  startCallButton: {
    backgroundColor: '#10b981',
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 20,
    paddingVertical: 18,
    paddingHorizontal: 20,
    marginTop: 22,
    shadowColor: '#10b981',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4,
    shadowRadius: 16,
    elevation: 8,
  },
  callIconBubble: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  callBigEmoji: {
    fontSize: 26,
  },
  callButtonTextCol: {
    flex: 1,
  },
  startCallTitle: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '800',
  },
  startCallSub: {
    color: 'rgba(255, 255, 255, 0.85)',
    fontSize: 12,
    marginTop: 2,
  },
  scenariosSection: {
    marginTop: 24,
  },
  sectionTitle: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '800',
  },
  sectionSubtitle: {
    color: '#94a3b8',
    fontSize: 12,
    marginTop: 3,
    marginBottom: 12,
  },
  scenariosGrid: {
    gap: 10,
  },
  scenarioCard: {
    backgroundColor: '#131b2e',
    borderRadius: 14,
    padding: 12,
    borderWidth: 1,
    borderColor: '#1e293b',
  },
  scenarioEmoji: {
    fontSize: 20,
    marginBottom: 4,
  },
  scenarioHeading: {
    color: '#ffffff',
    fontSize: 13,
    fontWeight: '700',
  },
  scenarioSnippet: {
    color: '#94a3b8',
    fontSize: 11,
    marginTop: 2,
    fontStyle: 'italic',
  },
  callerInfoBox: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 20,
    backgroundColor: '#0f172a',
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#1e293b',
  },
  callerInfoLabel: {
    color: '#64748b',
    fontSize: 12,
    fontWeight: '600',
    marginRight: 6,
  },
  callerInfoValue: {
    color: '#f8fafc',
    fontSize: 12,
    fontWeight: '700',
  },
  ticketsContent: {
    padding: 16,
    paddingBottom: 40,
  },
  ticketsHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 14,
  },
  ticketsTitle: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '800',
  },
  refreshBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: '#1e293b',
    borderRadius: 8,
  },
  refreshText: {
    color: '#818cf8',
    fontSize: 12,
    fontWeight: '700',
  },
  emptyTickets: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyEmoji: {
    fontSize: 50,
    marginBottom: 12,
  },
  emptyTitle: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '700',
  },
  emptySubtitle: {
    color: '#94a3b8',
    fontSize: 13,
    textAlign: 'center',
    marginTop: 6,
    paddingHorizontal: 20,
  },
  ticketCard: {
    backgroundColor: '#131b2e',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: '#1e293b',
    marginBottom: 12,
  },
  ticketCardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  ticketNumber: {
    color: '#6366f1',
    fontSize: 14,
    fontWeight: '800',
  },
  ticketBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  badgeOpen: {
    backgroundColor: 'rgba(234, 179, 8, 0.2)',
  },
  badgeSolved: {
    backgroundColor: 'rgba(16, 185, 129, 0.2)',
  },
  ticketBadgeText: {
    color: '#ffffff',
    fontSize: 11,
    fontWeight: '700',
  },
  ticketSubject: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '700',
    marginTop: 6,
  },
  ticketSummaryBox: {
    backgroundColor: '#0b0f19',
    borderRadius: 10,
    padding: 10,
    marginTop: 10,
  },
  summaryLabel: {
    color: '#818cf8',
    fontSize: 11,
    fontWeight: '700',
    marginBottom: 2,
  },
  summaryText: {
    color: '#cbd5e1',
    fontSize: 12,
    lineHeight: 17,
  },
  solutionBox: {
    backgroundColor: 'rgba(16, 185, 129, 0.1)',
    borderRadius: 10,
    padding: 10,
    marginTop: 8,
    borderWidth: 1,
    borderColor: 'rgba(16, 185, 129, 0.3)',
  },
  solutionTitle: {
    color: '#10b981',
    fontSize: 11,
    fontWeight: '700',
    marginBottom: 2,
  },
  solutionText: {
    color: '#e2e8f0',
    fontSize: 12,
    lineHeight: 17,
  },
  ticketFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 12,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#1e293b',
  },
  ticketMeta: {
    color: '#64748b',
    fontSize: 11,
  },

  // --------------------------------------------------------------------------
  // UNIFIED CALL MODAL STYLES
  // --------------------------------------------------------------------------
  callModalContainer: {
    flex: 1,
    backgroundColor: '#050811',
    paddingTop: Platform.OS === 'android' ? (StatusBar.currentHeight || 0) : 44,
  },
  incomingContent: {
    flex: 1,
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 50,
    paddingHorizontal: 24,
  },
  incomingTop: {
    alignItems: 'center',
  },
  incomingCompany: {
    color: '#818cf8',
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 2,
  },
  incomingSub: {
    color: '#94a3b8',
    fontSize: 14,
    marginTop: 4,
  },
  incomingAvatarRing: {
    width: 140,
    height: 140,
    borderRadius: 70,
    backgroundColor: 'rgba(99, 102, 241, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#6366f1',
  },
  incomingEmoji: {
    fontSize: 64,
  },
  callerNameText: {
    color: '#ffffff',
    fontSize: 26,
    fontWeight: '800',
    marginTop: -20,
  },
  ticketContextBadge: {
    color: '#10b981',
    fontSize: 14,
    fontWeight: '700',
    backgroundColor: 'rgba(16, 185, 129, 0.15)',
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 20,
  },
  solutionPreviewCard: {
    backgroundColor: '#131b2e',
    padding: 16,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#1e293b',
    width: '100%',
  },
  solutionPreviewTitle: {
    color: '#818cf8',
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 4,
  },
  solutionPreviewSubject: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '700',
    marginBottom: 4,
  },
  solutionPreviewText: {
    color: '#cbd5e1',
    fontSize: 13,
    lineHeight: 19,
  },
  incomingActionsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    width: '100%',
    paddingBottom: 20,
  },
  rejectBtn: {
    alignItems: 'center',
  },
  acceptBtn: {
    alignItems: 'center',
  },
  actionBtnIcon: {
    fontSize: 30,
    color: '#ffffff',
    backgroundColor: '#ef4444',
    width: 76,
    height: 76,
    borderRadius: 38,
    textAlign: 'center',
    textAlignVertical: 'center',
    lineHeight: 76,
    overflow: 'hidden',
    marginBottom: 8,
  },
  actionBtnLabel: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '700',
  },
  callTopBar: {
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#131b2e',
  },
  callCompanyName: {
    color: '#818cf8',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
  },
  callAgentSubtitle: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '700',
    marginTop: 2,
  },
  callStatusBadgeWrapper: {
    marginTop: 8,
  },
  statePill: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 5,
    borderRadius: 20,
    borderWidth: 1,
  },
  statePillText: {
    fontSize: 12,
    fontWeight: '700',
  },
  callTimerText: {
    color: '#94a3b8',
    fontSize: 13,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    letterSpacing: 1,
    marginTop: 6,
  },
  callAvatarSection: {
    alignItems: 'center',
    paddingVertical: 6,
  },
  avatarGlowCircle: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: 'rgba(99, 102, 241, 0.15)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 6,
  },
  callAvatarCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#1e1b4b',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#6366f1',
  },
  callAvatarEmoji: {
    fontSize: 40,
  },
  callAgentName: {
    color: '#ffffff',
    fontSize: 20,
    fontWeight: '800',
  },
  callAgentRole: {
    color: '#94a3b8',
    fontSize: 12,
    marginTop: 1,
    marginBottom: 8,
  },
  equalizerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 44,
    gap: 6,
  },
  eqBar: {
    width: 6,
    borderRadius: 3,
  },
  activeTicketBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(16, 185, 129, 0.15)',
    borderColor: '#10b981',
    borderWidth: 1,
    marginHorizontal: 18,
    padding: 8,
    borderRadius: 12,
    marginBottom: 6,
  },
  activeTicketIcon: {
    fontSize: 18,
    marginRight: 10,
  },
  activeTicketTitle: {
    color: '#10b981',
    fontWeight: '800',
    fontSize: 12,
  },
  activeTicketNumber: {
    color: '#e2e8f0',
    fontSize: 11,
    marginTop: 1,
  },
  transcriptContainer: {
    flex: 1,
    marginHorizontal: 16,
    backgroundColor: 'rgba(19, 27, 46, 0.65)',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#1e293b',
    paddingHorizontal: 12,
  },
  transcriptScroll: {
    flex: 1,
  },
  chatBubble: {
    maxWidth: '85%',
    padding: 12,
    borderRadius: 16,
    marginBottom: 10,
  },
  agentBubble: {
    alignSelf: 'flex-start',
    backgroundColor: '#1e293b',
    borderBottomLeftRadius: 4,
  },
  userBubble: {
    alignSelf: 'flex-end',
    backgroundColor: '#4338ca',
    borderBottomRightRadius: 4,
  },
  bubbleSpeaker: {
    color: '#a5b4fc',
    fontSize: 10,
    fontWeight: '800',
    marginBottom: 3,
    textTransform: 'uppercase',
  },
  bubbleContent: {
    color: '#ffffff',
    fontSize: 13,
    lineHeight: 18,
  },
  handsfreeControlCard: {
    marginHorizontal: 16,
    backgroundColor: '#131b2e',
    borderRadius: 16,
    padding: 12,
    borderWidth: 1,
    borderColor: '#1e293b',
    marginTop: 8,
  },
  handsfreeHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  handsfreeStatusLabel: {
    color: '#f8fafc',
    fontSize: 12,
    fontWeight: '700',
  },
  forceSendBtn: {
    backgroundColor: '#6366f1',
    borderRadius: 12,
    paddingVertical: 10,
    alignItems: 'center',
    marginTop: 8,
  },
  forceSendBtnText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: '700',
  },
  callBottomControls: {
    flexDirection: 'row',
    justifyContent: 'space-evenly',
    alignItems: 'center',
    paddingVertical: 16,
    paddingBottom: 22,
  },
  controlBtnWrapper: {
    alignItems: 'center',
  },
  subControlBtn: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: '#1e293b',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 4,
  },
  subControlIcon: {
    fontSize: 20,
  },
  subControlLabel: {
    color: '#94a3b8',
    fontSize: 11,
    fontWeight: '600',
  },
  hangupButton: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#ef4444',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#ef4444',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.5,
    shadowRadius: 12,
    elevation: 8,
  },
  hangupIcon: {
    fontSize: 30,
    transform: [{ rotate: '135deg' }],
  },
  settingsOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.7)',
    justifyContent: 'center',
    padding: 24,
  },
  settingsCard: {
    backgroundColor: '#131b2e',
    borderRadius: 20,
    padding: 24,
    borderWidth: 1,
    borderColor: '#334155',
  },
  settingsTitle: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '800',
    marginBottom: 16,
  },
  inputLabel: {
    color: '#94a3b8',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 10,
    marginBottom: 6,
  },
  settingsInputBox: {
    backgroundColor: '#0f172a',
    borderWidth: 1,
    borderColor: '#334155',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  settingsInputText: {
    color: '#ffffff',
    fontSize: 14,
  },
  saveBtn: {
    backgroundColor: '#6366f1',
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 20,
  },
  saveBtnText: {
    color: '#ffffff',
    fontWeight: '700',
    fontSize: 14,
  },
});
