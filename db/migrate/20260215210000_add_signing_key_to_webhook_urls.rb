# frozen_string_literal: true

class AddSigningKeyToWebhookUrls < ActiveRecord::Migration[7.1]
  def change
    add_column :webhook_urls, :signing_key, :text
  end
end
