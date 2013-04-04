# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    configure do |config|
      config.set :logging, true
      config.set :logger, LOGGER
      config.set :show_exceptions, false
      config.set :root, File.expand_path('../v1', __FILE__)
    end

    register Sinatra::Pebblebed

    use Rack::ConditionalGet
    use Rack::PostBodyContentTypeParser
    use Rack::MethodOverride

    before do
      @configuration = Configuration.instance

      LOGGER.info "Processing #{request.url}"
      LOGGER.info "Params: #{params.inspect}"

      cache_control :private, :no_store, :must_revalidate

      if current_user
        LOGGER.info "Session user ID=#{current_user.id}"
      else
        LOGGER.info "No session user"
      end
      if (t_user = transitional_user)
        LOGGER.info "Transitional user ID=#{t_user.id}"
      else
        LOGGER.info "No transitional user"
      end
    end

    helpers do
      def logger
        LOGGER
      end

      def redirect_with_logging(url)
        LOGGER.info "Redirecting to #{url}"
        redirect_without_logging(url)
      end
      alias_method_chain :redirect, :logging

      def current_user
        return @current_user ||= user_from_checkpoint_session
      end

      def transitional_user=(user)
        if user != @transitional_user
          @transitional_user = user
          if user
            logger.info "Set transitional user ID=#{user.id}"
            session[:transitional_user] = {'user_id' => user.id, 'session_key' => current_session}
          else          
            logger.info "Reset transitional user"
            session[:transitional_user] = nil
          end
        end
      end

      def transitional_user
        if @have_transitional_user
          @transitional_user
        else
          @have_transitional_user = true
          @transitional_user = find_transitional_user
        end
      end

      def find_transitional_user
        user = user_from_oauth_token
        unless user
          if (info = session[:transitional_user]) and info.is_a?(Hash)
            if info['session_key'] == current_session
              user = User.alive.where(:id => info['user_id']).first
            else
              # Mismatch, discard transitional user
              session[:transitional_user] = nil
            end
          end
        end
        user
      end

      def user_from_checkpoint_session
        if @have_user_from_checkpoint_session
          @user_from_checkpoint_session
        else
          @have_user_from_checkpoint_session = true
          @user_from_checkpoint_session = find_user_from_checkpoint_session
        end
      end

      def find_user_from_checkpoint_session
        if (identity = current_identity)
          if (uid = pebbles.checkpoint.get(
            "/identities/#{identity['id']}/accounts/vanilla").fetch('account', {})['uid'])
            # TODO: Filter by logged_in?
            return User.alive.where(:id => uid).first
          end
        end
      end

      def user_from_oauth_token
        if (token = oauth_token)
          User.alive.where(:id => token.user_id).first
        end
      end

      # Parses request and returns OAuth access token object, if valid. If an invalid
      # token is provided, or the request is a malformed attempt at providing a token,
      # an appropriate '401 Unauthorized' response is returned to the client, and the
      # method returns false.
      def oauth_token
        @oauth_token ||= begin
          # Bearer tokens according to http://tools.ietf.org/html/draft-ietf-oauth-v2-bearer-03
          authorization_header = request.env['HTTP_AUTHORIZATION']
          if authorization_header =~ /^\s*Bearer\s+(.*)/
            token_string = $1
          else
            token_string = params[:oauth_token]
            token_string ||= params[:access_token]  # Legacy parameter
          end
          if token_string
            token = Token.where(:access_token => token_string).
              all(:include => :user).first
            if token.nil? or token.expired?
              logger.error("Invalid OAuth token")
              headers['WWW-Authenticate'] = %(Bearer error="invalid_token")
              halt 403, 'Invalid OAuth token'
            end
            token
          end
        end
      end

      # Require an OAuth token, or return a '401 Unauthorized' response. If the scope 
      # argument is provided, the scope is used to check for a sufficient scope.
      def oauth_token_required
        unless oauth_token
          headers['WWW-Authenticate'] = 'Bearer'
          halt 403, 'OAuth token required'
        end
      end

      def custom_template!(name, options = {})
        logger.info "Rendering custom template #{name}"
        response.headers['Content-Type'] = 'text/html'
        response.body = @store.render_template(name,
          :user => current_user,
          :variables => options[:variables])
        halt(options[:status] || 200)
      end

      def return_url=(url)
        @return_url = url
      end

      def return_url
        url = @return_url
        url ||= params[:return_url]
        url ||= @store.try(:default_url)
        url
      end

      def redirect_back
        redirect to(return_url)
      end

      def exception_to_error_symbol(exception)
        case exception
          when ActiveRecord::RecordInvalid
            errors = exception.record.errors
            if errors and errors.keys.any?
              [errors.values.first].flatten.first
            else
              'unknown_error'
            end
          else
            exception.class.name.gsub(/^.*::([^:]+)$/, '\1').underscore
        end
      end

      # Encode a params hash to a base64 string.
      def encode_params_base64(params)
        query = params.map { |(k, v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
        s = Base64.encode64(query)
        s.gsub!(/(\s|==$)/, '')
        s
      end

      # Decode params from string encoded with encode_params_base64.
      def decode_params_base64(s)
        parsed = CGI.parse(Base64.decode64("#{s}=="))
        params = Hash[*parsed.entries.map { |k, v| [k, v[0]] }.flatten]
        params.with_indifferent_access
      end

      def god?
        if (identity = current_identity)
          identity[:god]
        end
      end

      def god_required!(store = nil)
        unless god?
          halt 403, 'User must be god to perform this action'
        end
        if store and current_identity[:realm] != store.name
          halt 403, "User must be god in store '#{store.name}' to perform this action"
        end
      end

      def url_with_params(url, params)
        uri = URI.parse(self.url(url))
        
        query = CGI.parse(uri.query || '')
        query = HashWithIndifferentAccess[*query.entries.map { |k, v| [k, v[0]] }.flatten]
        query.merge!(params)

        uri.query = query.entries.map { |k, v|
          "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}&"
        }.join('&')
        uri.to_s
      end

      def hermes(store)
        Pebblebed::Connector.new(store.hermes_session, host: request.host).hermes
      end

      def send_nonce_to_mobile!(user, options = {})
        nonce = Nonce.new(
          :store => user.store,
          :key => user.mobile_number,
          :value => Nonce.generate_numeric_value,
          :user => user,
          :url => options[:return_url] || self.return_url,
          :context => options[:context],
          :endpoint => :mobile)
        nonce.delivery_status_key = hermes(user.store).post("/#{user.store.name}/messages/sms",
          :path => 'vanilla',
          :recipient_number => user.mobile_number,
          :text => user.store.render_template(:verification_code_sms,
            :format => :plaintext,
            :variables => {
              :context => options[:context],
              :code => nonce.value,
              :url => short_verification_url(nonce)
            })
          )["post"]["uid"]
        nonce.save!
        nonce
      end

      def send_nonce_to_email!(user, options = {})
        nonce = Nonce.create!(
          :store => user.store,
          :key => user.email_address,
          :value => Nonce.generate_alphanumeric_value,
          :user => user,
          :url => options[:return_url] || self.return_url,
          :endpoint => :email,
          :context => options[:context])

        email_data = user.store.render_template(:verification_code_email,
          :format => :json,
          :variables => {
            :context => :signup,
            :code => nonce.value,
            :url => short_verification_url(nonce)
          })

        message = {}
        message[:sender_email] = email_data['from'] || user.store.default_sender_email_address
        message[:recipient_email] = user.email_address,
        message[:subject] = email_data[:subject]
        message[:html] = email_data[:html] if email_data[:html]
        message[:text] = email_data[:text] if email_data[:text]
        message[:path] = 'vanilla'

        nonce.delivery_status_key = hermes(user.store).post(
          "/#{user.store.name}/messages/email", message)["post"]["uid"]
        nonce.save!
        nonce
      end
    end

    def self.get_or_post(*args, &block)
      [:get, :post].each do |method|
        send(method, *args, &block)
      end
    end

    error Sinatra::NotFound do |e|
      halt 404, 'Not found'
    end

    error Store::IdentificationError do |e|
      halt 403, e.message
    end

    error ActiveRecord::RecordInvalid do |e|
      LOGGER.error "Validation failed: #{e}"
      LOGGER.error e.record.inspect
      halt 400, e.message
    end

  end

end