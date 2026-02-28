# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendSubmitterInvitationSmsJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }
  let(:submitter) do
    create(:submitter, submission:, uuid: template.submitters.first['uuid'], phone: '+15559876543')
  end

  let(:sms_config) do
    { 'account_sid' => 'AC_test_sid', 'auth_token' => 'test_token', 'from_number' => '+15551234567' }
  end

  let(:twilio_url) { "https://api.twilio.com/2010-04-01/Accounts/#{sms_config['account_sid']}/Messages.json" }

  before do
    create(:encrypted_config, account:, key: EncryptedConfig::SMS_KEY, value: sms_config)
    create(:encrypted_config, key: EncryptedConfig::ESIGN_CERTS_KEY,
                              value: GenerateCertificate.call.transform_values(&:to_pem))
  end

  describe '#perform' do
    before do
      stub_request(:post, twilio_url)
        .to_return(status: 200, body: { 'sid' => 'SM_test_123', 'status' => 'queued' }.to_json)
    end

    it 'sends an SMS and creates a submission event with Twilio SID' do
      described_class.new.perform('submitter_id' => submitter.id)

      expect(WebMock).to have_requested(:post, twilio_url).once
      event = SubmissionEvent.last
      expect(event.event_type).to eq('send_sms')
      expect(event.data['twilio_sid']).to eq('SM_test_123')
    end

    it 'updates submitter sent_at' do
      described_class.new.perform('submitter_id' => submitter.id)

      expect(submitter.reload.sent_at).to be_present
    end

    it 'skips when submitter is completed' do
      submitter.update!(completed_at: Time.current)

      described_class.new.perform('submitter_id' => submitter.id)

      expect(WebMock).not_to have_requested(:post, twilio_url)
    end

    it 'skips when submission is archived' do
      submitter.submission.update!(archived_at: Time.current)

      described_class.new.perform('submitter_id' => submitter.id)

      expect(WebMock).not_to have_requested(:post, twilio_url)
    end

    it 'skips when submitter has no phone' do
      submitter.update!(phone: nil)

      described_class.new.perform('submitter_id' => submitter.id)

      expect(WebMock).not_to have_requested(:post, twilio_url)
    end

    it 'skips when no SMS config exists' do
      EncryptedConfig.find_by(account:, key: EncryptedConfig::SMS_KEY).destroy

      described_class.new.perform('submitter_id' => submitter.id)

      expect(WebMock).not_to have_requested(:post, twilio_url)
    end

    context 'when SMS fails with SmsError' do
      before do
        stub_request(:post, twilio_url)
          .to_return(status: 400, body: { 'message' => 'Invalid phone number' }.to_json)
      end

      it 'schedules a retry with incremented attempt' do
        expect {
          described_class.new.perform('submitter_id' => submitter.id)
        }.to change(described_class.jobs, :size).by(1)

        job = described_class.jobs.last
        expect(job['args'].first['attempt']).to eq(1)
      end

      it 'does not create a submission event' do
        described_class.new.perform('submitter_id' => submitter.id)

        expect(SubmissionEvent.where(submitter:, event_type: 'send_sms')).to be_empty
      end
    end

    context 'when max attempts reached' do
      before do
        stub_request(:post, twilio_url)
          .to_return(status: 400, body: { 'message' => 'Invalid phone number' }.to_json)
      end

      it 'does not schedule another retry' do
        expect {
          described_class.new.perform('submitter_id' => submitter.id, 'attempt' => 4)
        }.not_to change(described_class.jobs, :size)
      end
    end

    context 'when network timeout occurs' do
      before do
        stub_request(:post, twilio_url).to_timeout
      end

      it 'schedules a retry' do
        expect {
          described_class.new.perform('submitter_id' => submitter.id)
        }.to change(described_class.jobs, :size).by(1)
      end
    end
  end
end
