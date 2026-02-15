# frozen_string_literal: true

class EnquiriesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  def create
    head :ok
  end
end
