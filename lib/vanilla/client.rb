module Vanilla
  class Client < ActiveRecord::Base

    class InvalidRedirectUrl < Exception; end
      
    VALID_REDIRECT_URL_PROTOCOLS = %w(http https).freeze

    belongs_to :store
    has_many :authorizations
    has_many :tokens
    
    validates :store, :presence => {}
    validates :api_key, :presence => {}, :uniqueness => {}
    validates :secret, :presence => {}
    validates :title, :presence => {}
    validates :oauth_redirect_uri,
      :presence => {},
      :format => {
        :with => URI::regexp(VALID_REDIRECT_URL_PROTOCOLS)
      }

    before_validation :ensure_api_key_and_secret
    before_save :ensure_api_key_and_secret
        
    class << self
      
      # Shorthand way of finding app and then asking if request is allowed.
      def request_allowed_for_api_key?(api_key, request)
        app = ExternalApplication.find_by_api_key(api_key)
        if app
          return app.request_allowed?(request)
        else
          return false
        end
      end
      
      # Generate a new API key.
      def generate_api_key
        SecureRandom.random_number(2 ** 256).to_s(36)
      end

    end
    
    # Is the request allowed to use this API key?
    def request_allowed?(request)
      true
    end
    
    # Validate redirect URI as per OAuth-v2-13 section 2.1.1. We accept HTTP/HTTPS,
    # and the same host as the one stored in the application.
    def valid_redirect_uri?(uri)
      if uri
        ours = URI.parse(self.oauth_redirect_uri)
        theirs = URI.parse(uri)
        return false if ours.host != theirs.host
        return false unless VALID_REDIRECT_URL_PROTOCOLS.include?(theirs.scheme)

        # When giving another scheme, accept only the standard ports
        return false if (ours.scheme != theirs.scheme or ours.port != theirs.port) and not
          ((ours.scheme == 'http' and theirs.scheme == 'https' and
            ours.port == 80 and theirs.port == 443) or
           (ours.scheme == 'https' and theirs.scheme == 'http' and
            ours.port == 443 and theirs.port == 80))
      end
      true
    end
    
    # Given a client URI, 
    def merge_oauth_redirect_url(url, params = {})
      if url
        raise InvalidRedirectUrl.new(url) unless valid_redirect_uri?(url)
        uri = URI.parse(url)
      else
        uri = URI.parse(self.oauth_redirect_uri)
      end
      if uri.query.present?
        components = Hash[
          *CGI.parse(uri.query).entries.map { |k, v| [k, v[0]] }.flatten]
        components.merge!(params.stringify_keys)
      else
        components = params
      end
      if components.any?
        uri.query = components.map { |k, v|
          CGI.escape(k.to_s) + '=' + CGI.escape(v.to_s) }.join('&')
      else
        uri.query = nil
      end
      uri.to_s
    end

    protected
    
      def ensure_api_key_and_secret
        self.api_key ||= self.class.generate_api_key
        self.secret ||= self.class.generate_api_key
        true
      end

  end
end