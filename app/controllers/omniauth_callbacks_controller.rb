# frozen_string_literal: true

class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :google_oauth2

  def google_oauth2
    user = Users.from_omniauth(request.env['omniauth.auth'])

    if user&.active_for_authentication?
      sign_in_and_redirect(user, event: :authentication)
    else
      redirect_to new_user_session_path, alert: I18n.t('user_not_found')
    end
  end

  def failure
    redirect_to new_user_session_path, alert: I18n.t('authentication_failed')
  end
end
