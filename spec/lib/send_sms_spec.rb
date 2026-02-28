# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendSms do
  let(:account_sid) { 'AC_test_sid' }
  let(:auth_token) { 'test_token' }
  let(:from_number) { '+15551234567' }
  let(:to_number) { '+15559876543' }
  let(:body) { 'Test message' }
  let(:twilio_url) { "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json" }

  let(:call_params) do
    { to: to_number, body:, account_sid:, auth_token:, from_number: }
  end

  describe '.call' do
    it 'returns parsed JSON on success' do
      stub_request(:post, twilio_url)
        .to_return(status: 200, body: { 'sid' => 'SM123', 'status' => 'queued' }.to_json)

      result = described_class.call(**call_params)

      expect(result).to eq({ 'sid' => 'SM123', 'status' => 'queued' })
    end

    it 'returns empty hash when success body is not parseable JSON' do
      stub_request(:post, twilio_url)
        .to_return(status: 200, body: 'not json')

      result = described_class.call(**call_params)

      expect(result).to eq({})
    end

    it 'raises SmsError with message on 4xx error' do
      stub_request(:post, twilio_url)
        .to_return(status: 400, body: { 'message' => 'Invalid phone number' }.to_json)

      expect { described_class.call(**call_params) }
        .to raise_error(SendSms::SmsError, 'Invalid phone number')
    end

    it 'raises SmsError with message on 5xx error' do
      stub_request(:post, twilio_url)
        .to_return(status: 500, body: { 'message' => 'Internal error' }.to_json)

      expect { described_class.call(**call_params) }
        .to raise_error(SendSms::SmsError, 'Internal error')
    end

    it 'raises SmsError with raw body when error response is not parseable JSON' do
      stub_request(:post, twilio_url)
        .to_return(status: 400, body: 'bad gateway')

      expect { described_class.call(**call_params) }
        .to raise_error(SendSms::SmsError, 'bad gateway')
    end

    it 'propagates Faraday::TimeoutError on network timeout' do
      stub_request(:post, twilio_url).to_timeout

      expect { described_class.call(**call_params) }
        .to raise_error(Faraday::ConnectionFailed)
    end

    it 'sets open_timeout and read_timeout on the request' do
      stub_request(:post, twilio_url)
        .to_return(status: 200, body: { 'sid' => 'SM123' }.to_json)

      described_class.call(**call_params)

      expect(WebMock).to have_requested(:post, twilio_url).once
    end
  end
end
