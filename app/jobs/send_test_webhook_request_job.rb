# frozen_string_literal: true

class SendTestWebhookRequestJob
  include Sidekiq::Job

  sidekiq_options retry: 0

  USER_AGENT = 'DocuSeal.com Webhook'

  HttpsError = Class.new(StandardError)
  LocalhostError = Class.new(StandardError)

  def perform(params = {})
    submitter = Submitter.find_by(id: params['submitter_id'])

    return unless submitter

    webhook_url = WebhookUrl.find_by(id: params['webhook_url_id'])

    return unless webhook_url

    if Docuseal.multitenant?
      uri = begin
        URI(webhook_url.url)
      rescue URI::Error
        Addressable::URI.parse(webhook_url.url).normalize
      end

      raise HttpsError, 'Only HTTPS is allowed.' if uri.scheme != 'https'
      raise LocalhostError, "Can't send to localhost." if uri.host.in?(SendWebhookRequest::LOCALHOSTS)
    end

    body = {
      event_type: 'form.completed',
      timestamp: Time.current.iso8601,
      data: Submitters::SerializeForWebhook.call(submitter)
    }.to_json

    key = webhook_url.ensure_signing_key!
    timestamp = Time.current.to_i.to_s
    signature = OpenSSL::HMAC.hexdigest('SHA256', key, "#{timestamp}.#{body}")

    Faraday.post(webhook_url.url, body,
                 'Content-Type' => 'application/json',
                 'User-Agent' => USER_AGENT,
                 'X-Webhook-Signature' => "sha256=#{signature}",
                 'X-Webhook-Timestamp' => timestamp,
                 'X-Webhook-Request-Id' => SecureRandom.uuid,
                 **webhook_url.secret.to_h)
  end
end
