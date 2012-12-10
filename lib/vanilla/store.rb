# encoding: utf-8

module Vanilla
  class Store < ActiveRecord::Base

    class TemplateRenderingError < StandardError; end

    class IdentificationError < StandardError
      def initialize(identification)
        @identification = identification
      end
      attr_reader :identification
    end
    class AuthenticationError < IdentificationError; end
    class IdentificationNotRecognized < AuthenticationError; end
    class PasswordMismatch < AuthenticationError; end
    class MobileNotVerified < AuthenticationError; end
    class EmailNotVerified < AuthenticationError; end

    DEFAULT_USER_NAME_MINIMUM_LENGTH = 5
    DEFAULT_USER_NAME_MAXIMUM_LENGTH = 25
    DEFAULT_USER_NAME_PATTERN = /\A[[:alpha:]0-9_., '`´-]+\z/.freeze

    serialize :scopes
    serialize :login_methods

    has_many :clients
    has_many :users

    if ENV['RACK_ENV'] != 'production'
      after_find :update_attributes_from_overrides
      after_initialize :update_attributes_from_overrides
    end
    before_validation :ensure_secret

    validates :name,
      :presence => {},
      :format => {:with => /\A[[:alnum:]_-]+\z/mi}
    validates :template_url, :presence => {}
    validates :default_url, :presence => {}
    validates :secret, :presence => {}

    class << self
      def environment_specific_override_for(store_name, attribute)
        environment_specific_overrides.fetch(store_name.to_s, {})[attribute]
      end

      def environment_specific_overrides
        @environment_specific_overrides ||= load_environment_specific_overrides
      end

      def load_environment_specific_overrides
        file_name = File.expand_path('../../../config/overrides.yml', __FILE__)
        config = load_environment_specific_overrides_from(file_name)
        if config.any?
          LOGGER.info "Loaded environment-specific overrides from #{file_name}"
        end
        config
      end

      def load_environment_specific_overrides_from(file_name, env = ENV['RACK_ENV'])
        config = HashWithIndifferentAccess.new
        begin
          config.merge!((YAML.load(File.open(file_name, 'r:utf-8')) || {}).fetch(env, {}))
        rescue Errno::ENOENT
          # Ignore
        end
        config
      end
    end

    def environment_specific_override_for(attribute)
      self.class.environment_specific_override_for(self.name, attribute)
    end

    def minimum_user_name_length
      read_attribute(:minimum_user_name_length) || DEFAULT_USER_NAME_MINIMUM_LENGTH
    end

    def maximum_user_name_length
      read_attribute(:maximum_user_name_length) || DEFAULT_USER_NAME_MAXIMUM_LENGTH
    end

    def user_name_pattern
      if (pattern = read_attribute(:user_name_pattern))
        Regexp.new(pattern)
      else
        DEFAULT_USER_NAME_PATTERN
      end
    end

    def user_name_pattern=(value)
      write_attribute(:user_name_pattern, value.to_s)
    end

    def send_sms!(options)
      message = Pebblebed::Connector.new(self.hermes_session).hermes.post(
        "/#{self.name}/messages/sms", options.slice(:recipient_number, :text).merge(:path => "vanilla"))
      message["post"]["uid"]
    end

    def send_email!(options)
      logger.debug { "Sending email: #{options.inspect}" }
      message = {}
      message[:sender_email] = self.default_sender_email_address
      message[:recipient_email] = options[:recipient_address]
      message[:subject] = options[:subject]
      message[:html] = options[:html] if options[:html]
      message[:text] = options[:text] if options[:text]
      message = Pebblebed::Connector.new(self.hermes_session).hermes.post(
        "/#{self.name}/messages/email", message.merge(:path => "vanilla"))
      message["post"]["uid"]
    end

    def scopes
      super || {}
    end

    def scopes=(hash)
      super(hash.stringify_keys)
    end

    def default_scope
      self.scopes.keys.first.try(:to_s)
    end

    def parse_scopes(s)
      scopes = Token.parse_scopes(s)
      scopes &= self.scopes.keys
      scopes = [default_scope] if scopes.empty?
      scopes
    end

    def login_methods
      super || [:email, :mobile, :name]
    end

    def authenticate(identification, password)
      user, _ = identify(identification)
      raise PasswordMismatch, identification unless user.password_match?(password)
      user
    end

    def identify(identification, permitted_methods = nil)
      if permitted_methods
        permitted_methods &= self.login_methods
      else
        permitted_methods = self.login_methods
      end

      if User.mobile_valid?(identification)
        if permitted_methods.include?(:mobile)
          if (user = User.active.having_mobile(identification).first)
            raise MobileNotVerified, identification unless user.mobile_verified?
            return user, :mobile
          end
        end
      elsif User.email_valid?(identification)
        if permitted_methods.include?(:email)
          if (user = User.active.having_email(identification).first)
            raise EmailNotVerified, identification unless user.email_verified?
            return user, :email
          end
        end
      end

      if permitted_methods.include?(:name)
        users = User.active.having_name(identification).all(:limit => 2)
        if users.length == 1
          return users.first, :name  # Only support matching a single user
        end
      end

      raise IdentificationNotRecognized, identification
    end

    def render_template(name, options = {})
      format = options[:format] || :html

      uri = URI.parse(self.template_url)
      uri.query << "&" if uri.query
      uri.query ||= ''
      uri.query << "template=#{name}"
      uri.query << "&format=#{format}"
      if (user = options[:user])
        uri.query << "&uid=#{user.id}"
      end
      
      logger.info "Rendering template URL: #{uri}"
      if (variables = options[:variables])
        body = JSON.dump(variables.stringify_keys)
      end
      response = Excon.post(uri.to_s,
        :body => body,
        :headers => {
          'Content-Type' => 'application/json',
          'Accept' =>
            case format
              when :json then 'application/json'
              when :plaintext then 'text/plain'
              when :html then 'text/html'
              else '*/*'
            end
        })
      unless response.status == 200
        raise TemplateRenderingError, "Server returned #{response.status} for template #{name}"
      end
      body = response.body
      body.force_encoding($1) if response.headers['Content-Type'] =~ /charset=([^\s]+)/
      body = JSON.parse(body) if options[:format] == :json
      body
    rescue Excon::Errors::SocketError => e
      raise TemplateRenderingError, "Server could not render template: #{e}"
    end

    def sign_with_secret(data)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, self.secret, data.to_s)
    end

    private

      def ensure_secret
        self.secret ||= SecureRandom.random_number(2 ** 256).to_s(36)
        true
      end

      def update_attributes_from_overrides
        klass = (class << self; self; end)
        attributes = self.class.environment_specific_overrides.fetch(self.name, {})
        attributes.each_pair do |key, value|
          klass.send(:define_method, key) { value }
        end
        true
      end

  end
end