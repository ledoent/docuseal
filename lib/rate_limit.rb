# frozen_string_literal: true

module RateLimit
  LimitApproached = Class.new(StandardError)

  STORE = begin
    redis_url = ENV.fetch('REDIS_URL', nil)
    if redis_url.present?
      ActiveSupport::Cache::RedisCacheStore.new(url: redis_url, namespace: 'rate_limit')
    else
      ActiveSupport::Cache::MemoryStore.new
    end
  rescue StandardError
    ActiveSupport::Cache::MemoryStore.new
  end

  module_function

  def call(key, limit:, ttl:, enabled: Docuseal.multitenant?)
    return true unless enabled

    value = STORE.increment(key, 1, expires_in: ttl)

    raise LimitApproached if value > limit

    true
  end
end
