require 'spec_helper'

include WebMock::API
include Vanilla

describe 'OAuth' do

  include Rack::Test::Methods

  def app
    TestVanillaV1
  end

  let! :store do
    Store.create!(
      :name => 'mystore',
      :template_url => 'http://example.com/template',
      :default_url => 'http://example.com/',
      :scopes => {
        'basic' => 'Just basic stuff',
        'extended' => 'Bags of stuff'
      })
  end

  let! :client do
    Client.create!(
      :store => store,
      :title => 'Bazooka Bill',
      :api_key => 'bazooka',
      :secret => 'bill',
      :oauth_redirect_uri => 'http://example.com/oauth')
  end

  let :user do
    User.create!(
      :store => store,
      :name => 'Ola Nordmann',
      :password => 'Zork123',
      :email_address => 'ola@nordmann.com',
      :email_verified => true,
      :mobile_number => '10001',
      :mobile_verified => true,
      :activated => true,
      :activated_at => Time.now)
  end

  before :each do
    checkpoint_session_identity!
  end
  
  describe "GET /oauth/authorize" do

    it 'fails if no client' do
      post '/oauth/authorize'
      last_response.status.should == 500
    end
    
    it 'fails if bad client' do
      post '/oauth/authorize', {:client_id => 'fubar'}
      last_response.status.should == 500
    end
    
    it 'redirects back with error if response type is missing' do
      post '/oauth/authorize', {:client_id => client.api_key}
      last_response.should be_redirect
      last_response.location.should =~ %r{^http://example.com/oauth}
      last_response.location.should =~ %r{error_description=.*}
      last_response.location.should =~ %r{error=.*}
    end

    context 'no transitional user' do
      it 'redirects to login' do
        post "/oauth/authorize", {:client_id => client.api_key, :response_type => 'code'}
        last_response.should be_redirect
        last_response.location.should =~ %r{/mystore/login}
        last_response.location.should =~ %r{return_url=.*%2Foauth%2Fauthorize}i
      end

      it 'preserves state parameter' do
        post "/oauth/authorize", {
          :client_id => client.api_key,
          :response_type => 'code',
          :state => 'illinois'}
        last_response.should be_redirect
        last_response.location.should =~ %r{return_url=.*state%3Dillinois}i
      end
    end

    context 'transitional user' do
      before :each do
        transitional_user!(user)
      end

      it 'renders authorization dialog' do
        stub = stub_request_for_template(:authorize,
          :body => proc { |body|
            vars = JSON.parse(body)
            valid = vars['scopes'] == {'basic' => 'Just basic stuff'}
            valid &&= vars['allow_url'] =~ %r{/oauth/allow}
            valid &&= vars['deny_url'] =~ %r{/oauth/deny}
            valid
          }
        ).to_return(
          :body => %{
            <form></form>
          }
        )
        post "/oauth/authorize", {:client_id => client.api_key, :response_type => 'code'}
        last_response.status.should == 200
        last_response.body.should =~ %r{<form></form>}
        stub.should have_been_requested
      end

      it 'logs out if "force_dialog" is true' do
        post "/oauth/authorize",
          :client_id => client.api_key,
          :response_type => 'code',
          :force_dialog => 'true'
        last_response.should be_redirect
        last_response.location.should =~ %r{/mystore/login}
        last_response.location.should =~ %r{return_url=.*%2Foauth%2Fauthorize}i
        transitional_user.should == nil
      end

      it 'skips authorization dialog if client has "skips_authorization_dialog" flag' do
        client.skips_authorization_dialog = true
        client.save!

        post "/oauth/authorize", {:client_id => client.api_key, :response_type => 'code'}
        last_response.should be_redirect

        authorization = Authorization.last
        authorization.should_not == nil
        authorization.user.should == user

        params = params_from_url(last_response.location)
        params['code'].should == authorization.code
      end

      context 'there is an existing authorization' do
        let! :authorization do
          Authorization.create!(
            :client => client,
            :code => 'BINGO',
            :scopes => [store.default_scope],
            :user => user,
            :redirect_url => client.oauth_redirect_uri)
        end

        it 'automatically uses existing authorization (but with new code) if matching default scope' do
          post "/oauth/authorize", {
            :client_id => client.api_key,
            :response_type => 'code'
          }
          last_response.should be_redirect
          old_code = authorization.code
          authorization.reload
          params = params_from_url(last_response.location)
          params['code'].should == authorization.code
          params['code'].should_not == old_code
        end

        it 'automatically uses existing authorization (but with new code) if matching scope' do
          post "/oauth/authorize", {
            :client_id => client.api_key,
            :response_type => 'code',
            :scope => store.default_scope
          }
          last_response.should be_redirect
          old_code = authorization.code
          authorization.reload
          params = params_from_url(last_response.location)
          params['code'].should == authorization.code
          params['code'].should_not == old_code
        end

        it 'ignores existing authorization if not matching scope' do
          stub = stub_request_for_template(:authorize)
          post "/oauth/authorize", {
            :client_id => client.api_key,
            :response_type => 'code',
            :scope => 'extended'
          }
          last_response.status.should == 200
          stub.should have_been_requested
        end
      end

      it 'preserves state parameter' do
        stub = stub_request_for_template(:authorize,
          :body => proc { |body|
            vars = JSON.parse(body)
            vars['allow_url'] =~ /state=illinois/ && 
              vars['deny_url'] =~ /state=illinois/
          })
        post "/oauth/authorize", {
          :client_id => client.api_key,
          :response_type => 'code',
          :state => 'illinois'
        }
        last_response.status.should == 200
        stub.should have_been_requested
      end
    end
  end

  describe "GET /oauth/allow" do
    it 'renders 404' do
      get '/oauth/allow'
      last_response.status.should == 404
    end
  end

  describe "POST /oauth/allow" do

    context 'when not logged in' do
      it 'renders 403' do
        post '/oauth/allow', {
          :client_id => client.api_key,
          :scope => store.scopes.keys.first,
          :implicit => false,
          :state => 'illinois'
        }
        last_response.status.should == 403
      end
    end

    context 'when logged in' do
      before :each do
        transitional_user!(user)
      end

      context 'for authorization code-type tokens' do
        it 'creates authorization code' do
          post '/oauth/allow', {
            :client_id => client.api_key,
            :scope => store.scopes.keys.first,
            :implicit => false,
            :state => 'illinois'
          }
          last_response.should be_redirect

          authorization = Authorization.last
          authorization.should_not == nil
          authorization.user.should == user
          authorization.code_expires_at.should <= (Time.now + 15.minutes)

          params = params_from_url(last_response.location)
          params['code'].should == authorization.code
          params['state'].should == 'illinois'
        end

        it 'rejects bad scope' do
          post '/oauth/allow', {
            :client_id => client.api_key,
            :scope => 'badscope',
            :implicit => false,
            :state => 'illinois'
          }
          last_response.status.should == 400
        end

        it 'rejects bad scope mixed with good scopes' do
          post '/oauth/allow', {
            :client_id => client.api_key,
            :scope => "#{store.scopes.keys.first},badscope",
            :implicit => false,
            :state => 'illinois'
          }
          last_response.status.should == 400
        end
      end

      context 'for implicit-grant type tokens' do
        it 'creates token' do
          post '/oauth/allow', {
            :client_id => client.api_key,
            :scope => store.scopes.keys.first,
            :implicit => true,
            :state => 'illinois'
          }
          last_response.should be_redirect

          authorization = Authorization.last
          authorization.should_not == nil
          authorization.user.should == user

          token = client.tokens.first
          token.should_not == nil
          token.user.should == user

          params = params_from_fragment(last_response.location)
          params['access_token'].should == token.access_token
          params['token_type'].should == 'bearer'
          params['refresh_token'].should == token.refresh_token
          params['scope'].should == store.scopes.keys.first
          params['state'].should == 'illinois'
        end
      end
    end

  end

  describe "GET /oauth/deny" do

    context 'when not logged in' do
      it 'renders 403' do
        post '/oauth/deny', {
          :client_id => client.api_key,
          :scope => store.scopes.keys.first,
          :implicit => false,
          :state => 'illinois'
        }
        last_response.status.should == 403
      end
    end

    context 'when logged in' do
      before :each do
        transitional_user!(user)
      end

      context 'for authorization code-type tokens' do
        it 'denies authorization' do
          post '/oauth/deny', {
            :client_id => client.api_key,
            :scope => store.scopes.keys.first,
            :implicit => false,
            :state => 'illinois'
          }
          last_response.should be_redirect

          uri = URI.parse(last_response.location)
          uri.query = nil
          uri.to_s.should == client.oauth_redirect_uri

          params = params_from_url(last_response.location)
          params.should_not include('code')
          params['state'].should == 'illinois'
          params['error'].should == 'access_denied'
          params.should include('error_description')
        end
      end

      context 'for implicit-grant type tokens' do
        it 'denies token' do
          post '/oauth/deny', {
            :client_id => client.api_key,
            :scope => store.scopes.keys.first,
            :implicit => true,
            :state => 'illinois'
          }
          last_response.should be_redirect
          last_response.location.gsub(/#.*/, '').should == client.oauth_redirect_uri

          params = params_from_fragment(last_response.location)
          params.should_not include('code')
          params['state'].should == 'illinois'
          params['error'].should == 'access_denied'
          params.should include('error_description')
        end
      end
    end

  end

  describe "GET /token" do

    context 'for grant type "authorization_code"' do
      let :authorization do
        Authorization.create!(
          :client => client,
          :code => 'BINGO',
          :scopes => [store.default_scope],
          :user => user,
          :redirect_url => client.oauth_redirect_uri)
      end

      it 'grants a token' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :code => authorization.code,
          :grant_type => 'authorization_code'
        }
        last_response.status.should == 200
        last_response.header['Content-Type'] == 'application/json'

        token = client.tokens.last
        token.should_not == nil

        vars = JSON.parse(last_response.body)
        vars['access_token'].should == token.access_token
        vars['token_type'].should == 'bearer'
        vars['refresh_token'].should == token.refresh_token
        vars['scope'].should == store.scopes.keys.first
      end

      it 'rejects invalid authorization code' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :code => 'fubar',
          :grant_type => 'authorization_code',
          :state => 'illinois'
        }
        last_response.status.should == 500
        vars = JSON.parse(last_response.body)
        vars['error'].should == 'invalid_grant'
        vars.should include('error_description')
      end

      it 'rejects expired authorization code' do
        authorization.code_expires_at = Time.now - 1.minute
        authorization.code_expired?.should == true
        authorization.save!

        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :code => authorization.code,
          :grant_type => 'authorization_code',
          :state => 'illinois'
        }
        last_response.status.should == 500
        vars = JSON.parse(last_response.body)
        vars['error'].should == 'invalid_grant'
        vars.should include('error_description')
      end

      it 'accepts different redirect URI with same scheme, host, port as in client configuration' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :code => authorization.code,
          :grant_type => 'authorization_code',
          :redirect_uri => 'http://example.com/dingbat'
        }
        last_response.status.should == 200
      end

      it 'accepts redirect URI with different scheme' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :code => authorization.code,
          :grant_type => 'authorization_code',
          :redirect_uri => "https://example.com"
        }
        last_response.status.should == 200
      end

      it 'rejects redirect URI with different host' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :code => authorization.code,
          :grant_type => 'authorization_code',
          :redirect_uri => "http://disney.com/"
        }
        last_response.status.should == 500
        vars = JSON.parse(last_response.body)
        vars['error'].should == 'invalid_grant'
        vars.should include('error_description')          
      end

      it 'rejects redirect URI with different port' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :code => authorization.code,
          :grant_type => 'authorization_code',
          :redirect_uri => "http://example.com:8080/"
        }
        last_response.status.should == 500
        vars = JSON.parse(last_response.body)
        vars['error'].should == 'invalid_grant'
        vars.should include('error_description')          
      end
    end

    context 'for grant type "refresh token"' do
      let :authorization do
        Authorization.create!(
          :client => client,
          :code => 'BINGO',
          :scopes => [store.default_scope],
          :user => user,
          :redirect_url => client.oauth_redirect_uri)
      end

      let :token do
        authorization.create_access_token!
      end

      it 'refreshes token' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :grant_type => 'refresh_token',
          :refresh_token => token.refresh_token,
          :scopes => token.scopes
        }
        last_response.status.should == 200
        last_response.header['Content-Type'] == 'application/json'

        new_token = Token.where(:id => token.id).first
        new_token.access_token.should_not == token.access_token
        new_token.refresh_token.should_not == token.refresh_token

        vars = JSON.parse(last_response.body)
        vars['access_token'].should == new_token.access_token
        vars['token_type'].should == 'bearer'
        vars['refresh_token'].should == new_token.refresh_token
        vars['scope'].should == store.scopes.keys.first
      end

      it 'returns error if token missing' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :grant_type => 'refresh_token',
          :scope => token.scopes
        }
        last_response.status.should == 500
        vars = JSON.parse(last_response.body)
        vars['error'].should == 'invalid_request'
        vars.should include('error_description')
      end

      it 'returns error if different scope' do
        post '/oauth/token', {
          :client_id => client.api_key,
          :client_secret => client.secret,
          :grant_type => 'refresh_token',
          :refresh_token => token.refresh_token,
          :scope => 'extended'
        }
        last_response.status.should == 500
        vars = JSON.parse(last_response.body)
        vars['error'].should == 'invalid_scope'
        vars.should include('error_description')
      end
    end

  end

end