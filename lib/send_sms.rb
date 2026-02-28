# frozen_string_literal: true

module SendSms
  SmsError = Class.new(StandardError)

  TWILIO_API_URL = 'https://api.twilio.com/2010-04-01/Accounts/%<account_sid>s/Messages.json'

  module_function

  def call(to:, body:, account_sid:, auth_token:, from_number:)
    url = format(TWILIO_API_URL, account_sid:)

    conn = Faraday.new do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end

    conn.basic_auth(account_sid, auth_token)

    response = conn.post(url, { 'To' => to, 'From' => from_number, 'Body' => body }) do |req|
      req.options.open_timeout = 8
      req.options.read_timeout = 15
    end

    return JSON.parse(response.body) if response.success?

    parsed = JSON.parse(response.body)
    message = parsed['message'] || response.body

    raise SmsError, message
  rescue JSON::ParserError
    return {} if response&.success?

    raise SmsError, response&.body
  end
end
