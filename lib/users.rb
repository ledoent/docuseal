# frozen_string_literal: true

module Users
  module_function

  def from_omniauth(oauth)
    User.find_by(email: oauth.info.email.to_s.downcase)
  end
end
