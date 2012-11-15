# encoding: utf-8

module Vanilla
  
  class V1 < Sinatra::Base

    helpers do
      def authorization_granted!(authorization)
        if @flow == :implicit_grant
          token_params = data_for_token(authorization.create_access_token!)
          redirect_to_app({:state => params[:state]}.merge(token_params))
        else
          # OAuth-v2-13 section 4.1.2: Respond with code and state
          redirect_to_app({:state => params[:state]}.merge(:code => authorization.code))
        end
      end
      
      def render_incorrect_invocation(options = {})
        logger.error(options[:error_description]) if options[:error_description]
        halt 500, options[:error_description]
      end
      
      def data_for_token(token)
        return {
          'access_token' => token.access_token,
          'token_type' => 'bearer',
          'refresh_token' => token.refresh_token,
          'scope' => token.scopes.join(',')
        }
      end
      
      def respond_with_token(token)
        headers['Content-Type'] = 'application/json'
        body = JSON.dump(data_for_token(token))
        logger.info "Responding with token: #{body.inspect}"
        halt 200, body
      end

      # Respond to client rquest with error.
      def respond_with_error(error, params = {})
        result = stringify_hash(params).merge('error' => error.to_s)
        logger.error("Returning error: #{result.inspect}")
        headers['Content-Type'] = 'application/json'
        halt 500, result.to_json
      end
      
      # Redirect to client application with an error condition.
      def redirect_to_app_with_error(error, extras = {})
        redirect_to_app(params.merge(extras).merge(:error => error))
      end

      # Redirect to client application.
      def redirect_to_app(params)
        logger.info "Redirecting to app: #{params.inspect}"
        if @flow == :implicit_grant
          redirect to(url_with_fragment(url_for_app, params))
        else
          redirect to(url_for_app(params))
        end
      end

      # Returns URL with a fragment added. The fragment may be a hash.
      def url_with_fragment(url, fragment)
        if Hash === fragment
          fragment = fragment.entries.map { |key, value| [CGI.escape(key.to_s), CGI.escape(value.to_s)].join('=') }.join('&')
        else
          fragment = CGI.escape(fragment)
        end
        uri = URI.parse(url)
        uri.fragment = fragment
        uri.to_s
      end
      
      def url_for_app(params = {})
        return @client.merge_oauth_redirect_url(self.params[:redirect_uri], params)
      end
      
      def stringify_hash(hash)
        return Hash[*hash.entries.map { |k, v| [k.to_s, v.to_s] }.flatten]
      end
    end

    # OAuth-v2-13 section 2.1.1: We need to support GET and POST
    get_or_post '/oauth/authorize' do
      @client = Client.where(:api_key => params[:client_id]).first
      unless @client
        render_incorrect_invocation(:error_description => 'Client not found')
      end
      @store = @client.store

      unless @client.valid_redirect_uri?(params[:redirect_uri])
        redirect_to_app_with_error(:invalid_request,
          :error_description => 'Invalid redirect URI')
      end

      # Support earlier draft code 'web_server'
      if params[:type] == 'web_server'
        params[:response_type] = 'code'
      end

      # OAuth-v2-13 section 4.1.1: Authorization code flow
      # OAuth-v2-13 section 4.2: Implicit grant flow
      case params[:response_type]
        when 'token'
          @flow = :implicit_grant
        when 'code'
          @flow = :authorization_code
        else
          redirect_to_app_with_error(:unsupported_response_type,
            :error_description => 'Unsupported response type, expected "code" or "token"')
      end

      if params[:force_dialog] == 'true'
        self.transitional_user = nil
        @user = nil
      else
        @user = transitional_user
      end

      unless @user
        logger.info "Showing login page"
        next_url = url_with_params(request.url,
          params.with_indifferent_access.except(:store, :captures, :splat).
          merge(:force_dialog => false))
        redirect url_with_params("/#{@store.name}/login",
          :target_url => params[:target_url] || next_url,
          :return_url => next_url)
      end

      @requested_scopes = @store.parse_scopes(params[:scope])

      # If authorization has been previously granted the application for a compatible
      # scope and the same redirect URI, we provide the authorization immediately
      @authorization = Authorization.where(
        :user_id => @user.id,
        :client_id => @client.id).first
      if @authorization
        if @authorization.match_scope?(@requested_scopes)
          @authorization.new_code!
          authorization_granted!(@authorization)
        else
          logger.info('Ignoring existing authorization as requested scope is not granted')
          @authorization = nil
        end
      end

      if @client.skips_authorization_dialog?
        @authorization = Authorization.create!(
          :user => @user,
          :client => @client,
          :redirect_url => @client.oauth_redirect_uri,
          :scopes => @requested_scopes)
        authorization_granted!(@authorization)
      end

      scope_hash = {}
      @requested_scopes.each do |scope|
        scope_hash[scope] = @store.scopes[scope]
      end
      url_params = "implicit=#{@flow == :implicit_grant}" \
        "&client_id=#{@client.api_key}" \
        "&scope=#{CGI.escape @requested_scopes.join(',')}"
      url_params << "&state=#{CGI.escape(params[:state])}" if params[:state]
      url_params << "&redirect_uri=#{CGI.escape(params[:redirect_uri])}" if params[:redirect_uri]
      custom_template!(:authorize, :variables => {
        :client_title => @client.title,
        :allow_url => url("/oauth/allow?#{url_params}"),
        :deny_url => url("/oauth/deny?#{url_params}"),
        :scopes => scope_hash
      })
    end

    post '/oauth/allow' do
      @user = transitional_user
      halt 403 unless @user

      @client = Client.where(:api_key => params[:client_id]).first
      unless @client
        render_incorrect_invocation(:error_description => 'Client not found')
      end
      @store = @client.store

      @authorization = Authorization.create!(
        :user => @user,
        :client => @client,
        :redirect_url => @client.oauth_redirect_uri,
        :scopes => params[:scope])

      @flow = params[:implicit] == 'true' ? :implicit_grant : :authorization_code
      authorization_granted!(@authorization)
    end
    
    post '/oauth/deny' do
      @user = transitional_user
      halt 403 unless @user

      @client = Client.where(:api_key => params[:client_id]).first
      unless @client
        render_incorrect_invocation(:error_description => 'Client not found')
      end
      @store = @client.store

      # OAuth-v2-13 section 4.1.2.1: Respond with error information and state
      @flow = params[:implicit] == 'true' ? :implicit_grant : :authorization_code
      redirect_to_app_with_error(:access_denied, :error_description => 'The user denied your request')
    end

    get_or_post '/oauth/token' do
      @client = Client.where(:api_key => params[:client_id]).first
      unless @client
        respond_with_error(:invalid_client,
          :error_description => 'Client not found')
      end
      @store = @client.store

      unless params[:client_secret] == @client.secret
        respond_with_error(:invalid_client,
          :error_description => 'Client secret does not match')
      end
      
      # Support earlier draft code 'web_server'
      if params[:type] == 'web_server'
        params[:grant_type] = 'authorization_code'
      end

      case params[:grant_type]
        when 'authorization_code'
          # OAuth-v2-13 section 4.1.3: Verify code and redirect URL
          @code = params[:code]
          unless @code
            respond_with_error(:invalid_grant,
              :error_description => 'Authorization code parameter missing')
          end
          
          @authorization = Authorization.where(
            :client_id => @client.id,
            :code => @code).first
          unless @authorization
            respond_with_error(:invalid_grant,
              :error_description => 'No authorization matching parameters')
          end
          unless @authorization.valid_redirect_uri?(params[:redirect_uri])
            respond_with_error(:invalid_grant,
              :error_description => 'Authorization redirect URI does not match')
          end
          if @authorization.code_expired?
            respond_with_error(:invalid_grant,
              :error_description => 'Authorization has expired')
          end

          # Create access token
          @token = @authorization.create_access_token!

        when 'refresh_token'
          # OAuth-v2-13 section 6: Verify token
          @refresh_token = params[:refresh_token]
          unless @refresh_token
            respond_with_error(:invalid_request,
              :error_description => 'Missing refresh token parameter') 
          end

          @token = Token.where(
            :refresh_token => @refresh_token,
            :client_id => @client.id).first
          unless @token
            respond_with_error(:invalid_request,
              :error_description => 'Unknown token') 
          end

          # OAuth-v2-13 section 6: Verify scope
          @scope = params[:scope]
          unless @token.match_scope?(@scope)
            respond_with_error(:invalid_scope,
              :error_description => 'Requested scope could not be granted')
          end

          @token.refresh!              

        else
          # OAuth-v2-13 section 4.1.3: Verify grant type
          respond_with_error(:unsupported_grant_type)
      end

      respond_with_token(@token)
    end

    # TODO: Change path to /oauth/...
    get '/users/omniauth_hash' do
      @user = transitional_user
      halt 403 unless @user
      headers['Content-Type'] = 'application/json'
      pg :omniauth_hash, :locals => {:user => @user}
    end

    error Client::InvalidRedirectUrl do
      render_incorrect_invocation(:error_description => 'Invalid redirect URI')
    end

  end

end
