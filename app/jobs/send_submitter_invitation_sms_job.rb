# frozen_string_literal: true

class SendSubmitterInvitationSmsJob
  include Sidekiq::Job

  def perform(params = {})
    submitter = Submitter.find(params['submitter_id'])

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

    SendSms.call(
      to: submitter.phone,
      body:,
      account_sid: sms_config['account_sid'],
      auth_token: sms_config['auth_token'],
      from_number: sms_config['from_number']
    )

    SubmissionEvent.create!(submitter:, event_type: 'send_sms')

    submitter.sent_at ||= Time.current
    submitter.save!
  end
end
