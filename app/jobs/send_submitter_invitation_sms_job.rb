# frozen_string_literal: true

class SendSubmitterInvitationSmsJob
  include Sidekiq::Job

  sidekiq_options retry: 0

  MAX_ATTEMPTS = 5

  def perform(params = {})
    submitter = Submitter.find(params['submitter_id'])
    attempt = params.fetch('attempt', 0).to_i

    return if submitter.completed_at?
    return if submitter.submission.archived_at?
    return if submitter.template&.archived_at?
    return if submitter.phone.blank?

    account = submitter.account
    sms_config = EncryptedConfig.find_by(account:, key: EncryptedConfig::SMS_KEY)&.value

    return if sms_config.blank?

    template_config = AccountConfig.find_by(account:, key: AccountConfig::SUBMITTER_INVITATION_SMS_KEY)
    message_template = template_config&.value.presence ||
                       AccountConfig::DEFAULT_VALUES[AccountConfig::SUBMITTER_INVITATION_SMS_KEY].call

    body = ReplaceEmailVariables.call(message_template, submitter:, tracking_event_type: 'click_sms')

    result = SendSms.call(
      to: submitter.phone,
      body:,
      account_sid: sms_config['account_sid'],
      auth_token: sms_config['auth_token'],
      from_number: sms_config['from_number']
    )

    event_data = {}
    event_data['twilio_sid'] = result['sid'] if result.is_a?(Hash) && result['sid'].present?

    SubmissionEvent.create!(submitter:, event_type: 'send_sms', data: event_data)

    submitter.sent_at ||= Time.current
    submitter.save!
  rescue SendSms::SmsError, Faraday::TimeoutError, Faraday::ConnectionFailed => e
    Rails.logger.error("SendSubmitterInvitationSmsJob failed for submitter #{params['submitter_id']} " \
                       "(attempt #{attempt}): #{e.class} - #{e.message}")

    next_attempt = attempt + 1

    if next_attempt < MAX_ATTEMPTS
      self.class.perform_in((2**next_attempt).minutes, params.merge('attempt' => next_attempt))
    else
      Rails.logger.error("SendSubmitterInvitationSmsJob exhausted #{MAX_ATTEMPTS} attempts " \
                         "for submitter #{params['submitter_id']}")
    end
  end
end
