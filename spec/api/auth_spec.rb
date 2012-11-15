require 'spec_helper'

include WebMock::API
include Vanilla

describe 'Authentication' do

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

  let :user do
    User.create!(
      :store => store,
      :name => 'Ola Nordmann',
      :password => 'Secret123',
      :email_address => 'ola@nordmann.com',
      :email_verified => true,
      :mobile_number => '10001',
      :mobile_verified => true,
      :activated => true,
      :activated_at => Time.now)
  end

  let :user_with_unverified_email do
    User.create!(
      :store => store,
      :name => 'Kari Nordmann',
      :password => 'Secret123',
      :email_address => 'kari@nordmann.com',
      :email_verified => false,
      :mobile_number => '10002',
      :mobile_verified => true,
      :activated => true,
      :activated_at => Time.now)
  end

  let :user_with_unverified_mobile do
    User.create!(
      :store => store,
      :name => 'Beate Nordmann',
      :password => 'Secret123',
      :email_address => 'beate@nordmann.com',
      :email_verified => true,
      :mobile_number => '10003',
      :mobile_verified => false,
      :activated => true,
      :activated_at => Time.now)
  end

  describe "POST /:store/auth" do

    before :each do
      checkpoint_session_identity!
    end

    it 'renders 404 if non-existent store' do
      post '/fubar/auth'
      last_response.status.should == 404
    end

    it 'returns user if authentication succeeds' do
      post '/mystore/auth', {:identification => user.name, :password => "Secret123"}
      last_response.status.should == 200
      data = JSON.parse(last_response.body)
      data.should include('user')
      %w(id name email_address email_verified mobile_number mobile_verified).each do |attr|
        data['user'][attr].should == user.send(attr)
      end
      data['user']['store'].should == store.name
    end

    it 'renders 403 if wrong password' do
      post '/mystore/auth', {:identification => "Bingo", :password => "WRONG"}
      last_response.status.should == 403
    end

    it 'renders 403 if non-existent user' do
      post '/mystore/auth', {:identification => "Bingo", :password => "Secret123"}
      last_response.status.should == 403
    end

  end

  describe "POST /:store/auth/:uid" do

    before :each do
      checkpoint_session_identity!
    end

    it 'renders 404 if non-existent store' do
      post "/fubar/auth/#{user.id}"
      last_response.status.should == 404
    end

    it 'returns user if authentication succeeds' do
      post "/mystore/auth/#{user.id}", {:password => "Secret123"}
      last_response.status.should == 200
      data = JSON.parse(last_response.body)
      data.should include('user')
      %w(id name email_address email_verified mobile_number mobile_verified).each do |attr|
        data['user'][attr].should == user.send(attr)
      end
      data['user']['store'].should == store.name
    end

    it 'renders 403 if wrong password' do
      post "/mystore/auth/#{user.id}", {:password => "WRONG"}
      last_response.status.should == 403
    end

    it 'renders 403 if non-existent user' do
      post "/mystore/auth/99999", {:password => "Secret123"}
      last_response.status.should == 404
    end

  end

  describe "GET /:store/login" do

    before :each do
      checkpoint_session_identity!
    end

    it 'renders 404 if non-existent store' do
      get '/fubar/login'
      last_response.status.should == 404
    end

    context 'when no transitional user' do
      it 'renders login form' do
        stub = stub_request_for_template(:login).to_return(
          :body => %{
            <form></form>
          }
        )
        get '/mystore/login'
        last_response.status.should == 200
        last_response.body.should =~ %r{<form></form>}
        stub.should have_been_requested
      end

      it 'passes default return URL to login form' do
        stub = stub_request_for_template(:login,
          :body => hash_including(:return_url => store.default_url))
        get '/mystore/login'
        stub.should have_been_requested
      end

      it 'passes custom return URL to login form' do
        stub = stub_request_for_template(:login,
          :body => hash_including(:return_url => 'http://example.org/custom'))
        get '/mystore/login', {:return_url => 'http://example.org/custom'}
        stub.should have_been_requested
      end

      it 'fails gracefully if login template fails to render' do
        stub = stub_request_for_template(:login).
          to_return(:status => 500)
        get '/mystore/login'
        last_response.status.should == 500
        stub.should have_been_requested
      end
    end

    context 'when transitional user' do
      before :each do
        transitional_user!(user)
      end

      it 'redirects back to default URL' do
        get '/mystore/login'
        last_response.status.should == 302
        last_response.headers['Location'].should == store.default_url
      end

      it 'redirects back to provided URL if set' do
        get '/mystore/login', {:return_url => 'http://example.org/'}
        last_response.status.should == 302
        last_response.headers['Location'].should == 'http://example.org/'
      end
    end

  end

  describe "GET /:store/login/:id" do

    before :each do
      checkpoint_session_identity!
    end

    it 'renders 404 if non-existent store' do
      get "/fubar/login/#{user.id}"
      last_response.status.should == 404
    end

    context 'when no transitional user' do
      it 'renders login form' do
        stub = stub_request_for_template(:login).to_return(
          :body => %{
            <form></form>
          }
        )
        get "/mystore/login/#{user.id}"
        last_response.status.should == 200
        last_response.body.should =~ %r{<form></form>}
        stub.should have_been_requested
      end
    end

    context 'when transitional user is different user' do
      let :other_user do
        User.create!(
          :store => store,
          :name => 'Alfred Nordmann',
          :password => 'Secret123',
          :email_address => 'alfred@nordmann.com',
          :email_verified => true,
          :mobile_number => '10004',
          :mobile_verified => true,
          :activated => true,
          :activated_at => Time.now)
      end

      before :each do
        transitional_user!(other_user)
      end

      it 'redirects back to default URL' do
        stub = stub_request_for_template(:login).to_return(
          :body => %{
            <form></form>
          }
        )
        get "/mystore/login/#{user.id}"
        last_response.status.should == 200
        stub.should have_been_requested
      end
    end

    context 'when transitional user is the right user' do
      before :each do
        transitional_user!(user)
      end

      it 'redirects back to default URL' do
        get "/mystore/login/#{user.id}"
        last_response.status.should == 302
        last_response.headers['Location'].should == store.default_url
      end
    end
  end

  describe "POST /:store/login" do

    before :each do
      checkpoint_session_identity!
    end

    it 'renders 404 if non-existent store' do
      post '/fubar/login'
      last_response.status.should == 404
    end

    context 'when no transitional user' do
      context 'when valid user' do
        after :each do
          last_response.status.should == 302
          last_response.headers['Location'].should == store.default_url
          transitional_user.should == user
        end

        [:as_is, :with_whitespace_padding, :uppercase, :mixed_case].each do |mode|
          it "logs in user with name #{mode.to_s.gsub('_', ' ')}" do
            post '/mystore/login', {
              :identification => case mode
                when :as_is
                  user.name
                when :with_whitespace_padding
                  "   #{user.name}\n"
                when :uppercase
                  user.name.upcase
                when :mixed_case
                  user.name.capitalize
              end,
              :password => 'Secret123'
            }
            last_response.should be_redirect
          end
        end

        [:as_is, :with_whitespace_padding, :uppercase, :mixed_case].each do |mode|
          it "logs in user by email address #{mode.to_s.gsub('_', ' ')}" do
            post '/mystore/login', {
              :identification => case mode
                when :as_is
                  user.email_address
                when :with_whitespace_padding
                  "   #{user.email_address}\n"
                when :uppercase
                  user.email_address.upcase
                when :mixed_case
                  user.email_address.capitalize
              end,
              :password => 'Secret123'
            }
            last_response.should be_redirect
          end
        end

        [:as_is, :with_whitespace_padding, :with_embedded_spaces].each do |mode|
          it "logs in user by mobile number #{mode.to_s.gsub('_', ' ')}" do
            post '/mystore/login', {
              :identification => case mode
                when :as_is
                  user.mobile_number
                when :with_whitespace_padding
                  "   #{user.mobile_number}\n"
                when :with_embedded_spaces
                  user.mobile_number.split(//).join(' ')
              end,
              :password => 'Secret123'
            }
            last_response.should be_redirect
          end
        end
      end

      context 'when invalid user' do
        after :each do
          last_response.status.should == 403
          transitional_user.should == nil
        end

        it 'rejects unknown email' do
          stub = stub_request_for_template(:login,
            :body => hash_including(
              :error => 'identification_not_recognized',
              :identification => 'fubar@example.com'))
          post '/mystore/login', {
            :identification => "fubar@example.com",
            :password => 'Secret123'
          }
          stub.should have_been_requested
        end

        it 'rejects unknown mobile' do
          stub = stub_request_for_template(:login,
            :body => hash_including(
              :error => 'identification_not_recognized',
              :identification => '666'))
          post '/mystore/login', {
            :identification => "666",
            :password => 'Secret123'
          }
          stub.should have_been_requested
        end

        it 'rejects wrong password' do
          stub = stub_request_for_template(:login,
            :body => hash_including(
              :error => 'password_mismatch',
              :identification => user.mobile_number))
          post '/mystore/login', {
            :identification => user.mobile_number,
            :password => 'WHAT IS THIS'
          }
          stub.should have_been_requested
        end

        it 'rejects unverified email' do
          stub = stub_request_for_template(:login,
            :body => hash_including(:error => 'email_not_verified'))
          post '/mystore/login', {
            :identification => user_with_unverified_email.email_address,
            :password => 'Secret123'
          }
          stub.should have_been_requested
        end

        it 'rejects unverified mobile' do
          stub = stub_request_for_template(:login,
            :body => hash_including(
              :error => 'mobile_not_verified',
              :identification => user_with_unverified_mobile.mobile_number))
          post '/mystore/login', {
            :identification => user_with_unverified_mobile.mobile_number,
            :password => 'Secret123'
          }
          stub.should have_been_requested
        end

        it 'rejects deleted user' do
          user.delete!
          stub = stub_request_for_template(:login,
            :body => hash_including(:error => 'identification_not_recognized'))
          post '/mystore/login', {
            :identification => user.email_address,
            :password => 'Secret123'
          }
          stub.should have_been_requested
        end

        it 'rejects un-activated user' do
          user.activated = false
          user.activated_at = nil
          user.save!
          stub = stub_request_for_template(:login,
            :body => hash_including(:error => 'identification_not_recognized'))
          post '/mystore/login', {
            :identification => user.email_address,
            :password => 'Secret123'
          }
          stub.should have_been_requested
        end

        it 'on failure, passes default return URL to login form' do
          stub = stub_request_for_template(:login,
            :body => hash_including(:return_url => store.default_url))
          post '/mystore/login'
          stub.should have_been_requested
        end

        it 'passes custom return URL to login form' do
          stub = stub_request_for_template(:login,
            :body => hash_including(:return_url => 'http://example.org/custom'))
          post '/mystore/login', {:return_url => 'http://example.org/custom'}
          stub.should have_been_requested
        end
      end

      it 'fails gracefully if login template fails to render' do
        stub = stub_request_for_template(:login).
          to_return(:status => 500)
        post '/mystore/login'
        last_response.status.should == 500
        stub.should have_been_requested
      end
    end

    context 'when transitional user' do
      before :each do
        transitional_user!(user)
      end

      it 'redirects back to default URL' do
        get '/mystore/login'
        last_response.status.should == 302
        last_response.headers['Location'].should == store.default_url
      end

      it 'redirects back to provided URL if set' do
        get '/mystore/login', {:return_url => 'http://example.org/'}
        last_response.status.should == 302
        last_response.headers['Location'].should == 'http://example.org/'
      end
    end

  end

  describe "POST /:store/logout" do

    before :each do
      checkpoint_session_identity!
    end

    it 'renders 404 if non-existent store' do
      post '/fubar/login'
      last_response.status.should == 404
    end

    context 'when no transitional user' do
      it 'ignores the action' do
        post '/mystore/logout'
        last_response.status.should == 302
        last_response.headers['Location'].should == store.default_url
      end
    end

    context 'when transitional user' do
      before :each do
        transitional_user!(user)
      end

      it 'logs the user out' do
        post '/mystore/logout'
        last_response.status.should == 302
        last_response.headers['Location'].should == store.default_url
        transitional_user.should == nil
      end
    end

  end

  describe "POST /:store/logout/:id" do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      post "/fubar/logout/#{user.id}"
      last_response.status.should == 404
    end

    context 'when user is god' do
      let :god_user do
        User.create!(
          :store => store,
          :name => 'Jesus Nordmann',
          :password => 'Secret123',
          :email_address => 'jesus@nordmann.com',
          :email_verified => true,
          :mobile_number => '10003',
          :mobile_verified => true,
          :activated => true,
          :activated_at => Time.now)
      end

      before :each do
        checkpoint_session_identity!(god_user, :god => true)
        user.logged_in = true
        user.save!
      end

      it 'logs the user out' do
        post "/mystore/logout/#{user.id}"
        last_response.status.should == 200
        user.reload
        user.logged_in.should == false
      end
    end

  end

end