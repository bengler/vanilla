module Vanilla
  class Token < ActiveRecord::Base

    belongs_to :client
    belongs_to :user
    
    serialize :scopes
    
    before_validation :generate_keys
    
    class << self
      
      def match_scope?(allowed_scope, check_scope)
        allowed_scope = parse_scopes(allowed_scope)
        check_scope = parse_scopes(check_scope)
        return check_scope.all? { |scope| allowed_scope.include?(scope) }
      end
      
      def parse_scopes(spec)
        if spec.is_a?(Array)
          scopes = spec.map(&:to_s)
        else
          scopes = spec.to_s.split(/[,\s]+/)
        end
        scopes.reject! { |s| s.blank? }
        scopes.uniq!
        scopes
      end

    end
    
    def expired?
      self.expires_at && self.expires_at <= Time.now
    end
    
    def active?
      !expired?
    end
    
    def invalidate!
      update_attribute(:invalidated_at, Time.now)
    end
    
    def match_scope?(scope)
      self.class.match_scope?(self.scopes, scope)
    end
    
    def refresh!
      self.access_token = nil
      self.refresh_token = nil
      self.generate_keys
      self.save!
    end
        
    protected
      
      def generate_keys
        self.access_token ||= SecureRandom.random_number(2 ** 256).to_s(36)
        self.refresh_token ||= SecureRandom.random_number(2 ** 256).to_s(36)
        true
      end

  end
end