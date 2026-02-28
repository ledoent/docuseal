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

      expect {
        described_class.call('test_key', limit: 3, ttl: 1.minute, enabled: true)
      }.to raise_error(RateLimit::LimitApproached)
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
end
