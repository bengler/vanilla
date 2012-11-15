module Vanilla
  class Nonce < ActiveRecord::Base

    belongs_to :store
    belongs_to :user

    before_validation :set_default_expiry

    scope :having_store, lambda { |store|
      where(:store_id => store.id)
    }
    scope :having_key, lambda { |key|
      where(:key => key)
    }
    scope :having_value, lambda { |value|
      where(:value => value)
    }

    class << self
      def generate_numeric_value(length = 5)
        (0..9).to_a.sample(length).join
      end

      def generate_alphanumeric_value(bits = 128)
        SecureRandom.random_number(2 ** bits).to_s(36)
      end
    end

    def expired?
      self.expires_at && self.expires_at <= Time.now
    end

    def expired!
      if not expired?
        self.expires_at = Time.now
        save(:validate => false)
      end
    end

    def endpoint=(v)
      super(v.try(:to_s))
    end

    def endpoint
      super.try(:to_sym)
    end

    def context=(v)
      super(v.try(:to_s))
    end

    def context
      super.try(:to_sym)
    end

    private

      def set_default_expiry
        self.expires_at ||= Time.now + 2.days
      end

  end
end