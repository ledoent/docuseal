# frozen_string_literal: true

class NewslettersController < ApplicationController
  skip_authorization_check

  def show; end

  def update
    redirect_to root_path
  end
end
