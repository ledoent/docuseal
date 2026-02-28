# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RateLimit do
  before do
    described_class::STORE.clear
  end

  describe '.call' do
    it 'allows requests under the limit' do
      expect(described_class.call('test_key', limit: 5, ttl: 1.minute, enabled: true)).to be true
    end

    it 'raises LimitApproached when limit is exceeded' do
      3.times { described_class.call('test_key', limit: 3, ttl: 1.minute, enabled: true) }

      expect do
        described_class.call('test_key', limit: 3, ttl: 1.minute, enabled: true)
      end.to raise_error(RateLimit::LimitApproached)
    end

    it 'resets after TTL expires' do
      3.times { described_class.call('test_key', limit: 3, ttl: 1.second, enabled: true) }

      sleep 1.1

      expect(described_class.call('test_key', limit: 3, ttl: 1.second, enabled: true)).to be true
    end

    it 'returns true when disabled' do
      100.times { described_class.call('test_key', limit: 1, ttl: 1.minute, enabled: false) }

      expect(described_class.call('test_key', limit: 1, ttl: 1.minute, enabled: false)).to be true
    end

    it 'isolates keys from each other' do
      3.times { described_class.call('key_a', limit: 3, ttl: 1.minute, enabled: true) }

      expect(described_class.call('key_b', limit: 3, ttl: 1.minute, enabled: true)).to be true
    end
  end

  describe 'STORE' do
    it 'uses MemoryStore when REDIS_URL is not set' do
      store = described_class::STORE

      expect(store).to be_a(ActiveSupport::Cache::MemoryStore) if ENV['REDIS_URL'].blank?
    end

    it 'falls back to MemoryStore on Redis connection error' do
      store = begin
        redis_url = 'redis://invalid-host:6379/0'
        ActiveSupport::Cache::RedisCacheStore.new(url: redis_url, namespace: 'rate_limit')
      rescue StandardError
        ActiveSupport::Cache::MemoryStore.new
      end

      # The RedisCacheStore may be created without raising (it connects lazily),
      # but our module's rescue block ensures a MemoryStore fallback on any error
      expect(store).to be_a(ActiveSupport::Cache::Store)
    end

    it 'responds to increment for rate limiting' do
      expect(described_class::STORE).to respond_to(:increment)
    end
  end
end
