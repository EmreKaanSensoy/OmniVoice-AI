require "net/http"
require "json"
require "open3"

class AzureSpeechService
  def self.speech_key
    ENV["AZURE_SPEECH_KEY"].presence || ENV["AZURE_OPENAI_API_KEY"].to_s.strip
  end

  def self.speech_region
    ENV["AZURE_SPEECH_REGION"].presence || "eastus2"
  end

  def self.ffmpeg_binary
    @ffmpeg_binary ||= begin
      candidates = [
        ENV["FFMPEG_PATH"],
        "C:/Users/senso/AppData/Local/Programs/Python/Python312/Lib/site-packages/static_ffmpeg/bin/win32/ffmpeg.exe",
        "ffmpeg"
      ].compact
      candidates.find do |cmd|
        File.exist?(cmd) || system("#{cmd} -version >nul 2>&1")
      end || "ffmpeg"
    end
  end

  # Converts any audio format (M4A, AAC, MP4, etc.) to 16kHz Mono 16-bit PCM WAV in memory
  def self.convert_to_pcm16_wav(raw_audio)
    return raw_audio if raw_audio.nil? || raw_audio.empty?

    binary = ffmpeg_binary
    stdout, stderr, status = Open3.capture3(
      binary, "-y", "-i", "pipe:0", "-ar", "16000", "-ac", "1", "-f", "wav", "pipe:1",
      stdin_data: raw_audio, binmode: true
    )

    if status.success? && stdout.bytesize > 44
      Rails.logger.info("[AzureSpeech] Converted #{raw_audio.bytesize} bytes audio to #{stdout.bytesize} bytes WAV (16kHz mono)")
      stdout
    else
      Rails.logger.warn("[AzureSpeech] FFmpeg conversion warning (status #{status.exitstatus}): #{stderr[0..200]}")
      raw_audio
    end
  rescue StandardError => e
    Rails.logger.error("[AzureSpeech] Audio conversion error: #{e.message}")
    raw_audio
  end

  def self.transcribe_audio(audio_data, content_type = "audio/mp4")
    return nil if audio_data.nil? || audio_data.empty?

    # Azure Speech Short-Audio REST API strictly requires 16kHz mono PCM WAV.
    # We dynamically convert mobile AAC/M4A input to 16kHz PCM WAV.
    wav_data = convert_to_pcm16_wav(audio_data)

    key = speech_key
    regions = [speech_region, "eastus2", "westeurope"].uniq

    regions.each do |region|
      uri = URI("https://#{region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=tr-TR")

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.read_timeout = 15
      http.open_timeout = 8

      req = Net::HTTP::Post.new(uri)
      req["Ocp-Apim-Subscription-Key"] = key
      req["Content-Type"] = "audio/wav; codecs=audio/pcm; samplerate=16000"
      req["Accept"] = "application/json"
      req.body = wav_data

      response = http.request(req)

      if response.code.to_i == 200
        parsed = JSON.parse(response.body) rescue {}
        status = parsed["RecognitionStatus"]
        text = parsed["DisplayText"].presence || parsed.dig("NBest", 0, "Display").presence

        if status == "Success" && text.present?
          Rails.logger.info("[AzureSpeech] Transcribed successfully (#{region}): #{text}")
          return text
        elsif status == "NoMatch" || status == "InitialSilenceTimeout"
          Rails.logger.info("[AzureSpeech] No speech match (#{region}): #{status}")
          return nil
        elsif text.present?
          Rails.logger.info("[AzureSpeech] Recognized text with status #{status}: #{text}")
          return text
        end
      else
        Rails.logger.warn("[AzureSpeech] STT Failed on #{region} (#{response.code}): #{response.body}")
      end
    rescue StandardError => e
      Rails.logger.error("[AzureSpeech] Exception on #{region}: #{e.message}")
    end

    nil
  end
end
