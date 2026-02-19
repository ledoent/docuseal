# frozen_string_literal: true

module Users
  module_function

  def from_omniauth(oauth)
    email = oauth.info.email.to_s.downcase
    user = User.find_by(email:)

    return user if user
    return nil unless auto_create_enabled?
    return nil unless domain_allowed?(email)

    create_from_oauth(oauth, email)
  end

  def auto_create_enabled?
    ENV['GOOGLE_AUTO_CREATE'].to_s.downcase.in?(%w[true 1 yes])
  end

  def domain_allowed?(email)
    domain = ENV['GOOGLE_ALLOWED_DOMAIN'].to_s.strip
    return true if domain.blank?

    email.end_with?("@#{domain.downcase}")
  end

  def create_from_oauth(oauth, email)
    account = Account.active.first
    return nil unless account

    role = ENV.fetch('GOOGLE_AUTO_CREATE_ROLE', User::ADMIN_ROLE)

    account.users.create!(
      email:,
      first_name: oauth.info.first_name.to_s,
      last_name: oauth.info.last_name.to_s,
      password: SecureRandom.hex(32),
      role:,
      confirmed_at: Time.current
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("OAuth auto-create failed for #{email}: #{e.message}")
    nil
  end
end
