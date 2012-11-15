module Vanilla
  class Authorization < ActiveRecord::Base

    belongs_to :user
    belongs_to :client
    has_many :tokens,
      :foreign_key => 'authorization_code',
      :primary_key => 'code',
      :dependent => :destroy

    serialize :scopes

    validates_each :scopes do |record, attr, value|
      unless Token.match_scope?(record.client.store.scopes.keys, value)
        record.errors.add(attr, 'has invalid scopes')
      end
    end

    before_validation :generate_code
    before_validation :set_default_expiry

    def scopes=(v)
      super([v].flatten.compact)
    end
    
    def code_expired?
      self.code_expires_at && self.code_expires_at <= Time.now
    end

    def match_scope?(scope)
      Token.match_scope?(self.scopes, scope)
    end
    
    def new_code!
      self.code = nil
      self.code_expires_at = nil
      set_default_expiry
      generate_code
      save!
    end
    
    # Is this a valid redirect URI for this authorization?
    def valid_redirect_uri?(uri)
      return self.client.valid_redirect_uri?(uri)
    end
    
    # Create a new access token from this authorization.
    def create_access_token!(attributes = {})
      # OAuth-v2-13 section 4.1.2: Destroy existing tokens issued on authorization code
      self.tokens.destroy_all
      
      return Token.create!({
        :user => self.user,
        :authorization_code => self.code,
        :client => self.client,
        :scopes => self.scopes
      }.merge(attributes))
    end
    
    private
    
      def generate_code
        self.code ||= SecureRandom.random_number(2 ** 128).to_s(36)
        true
      end
      
      def set_default_expiry
        self.code_expires_at ||= Time.now + 10.minutes
        true
      end

  end
end