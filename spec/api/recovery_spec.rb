require 'spec_helper'

include WebMock::API
include Vanilla

describe 'Recovery' do

  include Rack::Test::Methods

  def app
    TestVanillaV1
  end

  let! :store do
    Store.create!(
      :name => 'mystore',
      :template_url => 'http://example.com/template',
      :default_url => 'http://example.com/',
      :default_sender_email_address => 'Example <notifications@example.com>',
      :hermes_session => 'god',
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

  let :nonce do
    Nonce.create!(
      :user => user,
      :key => user.id,
      :value => '123456',
      :store => store)
  end

  let :expired_nonce do
    Nonce.create!(
      :user => user,
      :key => user.id,
      :value => '987654',
      :store => store,
      :expires_at => Time.now - 5.minutes)
  end

  describe 'GET /:store/recover' do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/recover'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'redirects to default store URL' do
        get "/mystore/recover"
        last_response.should be_redirect
        last_response.location.should =~ /^#{Regexp.escape(store.default_url)}/
      end

      it 'redirects to provided return URL' do
        get "/mystore/recover", :return_url => 'http://disney.com/'
        last_response.should be_redirect
        last_response.location.should =~ %r{^http://disney\.com/}
      end
    end

    context 'when not logged in' do
      before :each do
        checkpoint_session_identity!
      end

      it 'renders "recovery_request" template' do
        stub = stub_request_for_template(:recovery_request,
          :body => hash_including(:return_url => store.default_url))
        get "/mystore/recover"
        stub.should have_been_requested
      end
    end
  end

  describe 'POST /:store/recover' do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      post '/fubar/recover'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'redirects to default store URL' do
        post "/mystore/recover"
        last_response.should be_redirect
        last_response.location.should =~ /^#{Regexp.escape(store.default_url)}/
      end

      it 'redirects to provided return URL' do
        post "/mystore/recover", :return_url => 'http://disney.com/'
        last_response.should be_redirect
        last_response.location.should =~ %r{^http://disney\.com/}
      end
    end

    context 'when not logged in' do
      before :each do
        checkpoint_session_identity!
      end

      context 'using mobile' do
        it 'sends code via SMS, renders "recovery_code_validation" template' do
          template_stub = stub_request_for_template(:verification_code_sms,
            :query => hash_including(:format => 'plaintext'),
            :body => proc { |h|
              vars = JSON.parse(h)
              vars['code'].should =~ /\A[0-9]+\Z/
              vars['context'].should == 'recovery'
              vars['url'].should =~ %r{/mystore/v/}
              true
            })

          hermes_stub = stub_request(:post, %r{/api/hermes/v1/mystore/messages/sms}).
            with(:body => hash_including(:recipient_number => user.mobile_number)).
            to_return(:body =>  '{"post": {"uid": "post.hermes_message:mystore$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }')

          post "/mystore/recover", {:identification => user.mobile_number}
          last_response.should be_redirect

          template_stub.should have_been_requested
          hermes_stub.should have_been_requested
        end

        it 'rejects invalid mobile' do
          stub = stub_request_for_template(:recovery_request,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'identification_not_recognized'
            ))
          post "/mystore/recover", :identification => '12345'
          stub.should have_been_requested
        end

        it 'rejects unverified mobile' do
          stub = stub_request_for_template(:recovery_request,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'mobile_not_verified'
            ))
          post "/mystore/recover", :identification => user_with_unverified_mobile.mobile_number
          stub.should have_been_requested
        end
      end

      context 'using email' do
        it 'sends code via email, renders "recovery_code_validation" template' do
          stub1 = stub_request_for_template(:verification_code_email,
            :query => hash_including(:format => 'json'),
            :body => proc { |h|
              vars = JSON.parse(h)
              vars['code'].should =~ /\A[0-9a-z\/]+\Z/
              vars['url'].should =~ %r{/mystore/v/}
              true
            }).
            to_return(
              :body => JSON.dump(
                :subject => 'A code, my kingdom for a code',
                :text => "Code, blah blah"))

          stub2 = stub_request(:post, "http://example.org/api/hermes/v1/mystore/messages/email").
            with(:body => "{\"sender_email\":\"#{store.default_sender_email_address}\",\"recipient_email\":\"ola@nordmann.com\",\"subject\":\"A code, my kingdom for a code\",\"text\":\"Code, blah blah\",\"path\":\"vanilla\",\"session\":\"god\"}",
                 :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json'}).
            to_return(:status => 200, :body =>  '{"post": {"uid": "post.hermes_message:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }', :headers => {})


          stub3 = stub_request_for_template(:verification_code_sent,
            :body => proc { |h|
              vars = JSON.parse(h)
              vars['context'].should == 'recovery'
              vars['endpoint'].should == 'email'
              vars['delivery_status_key'].to_s.should == ''
              true
            })

          post "/mystore/recover", {:identification => user.email_address}
          last_response.status.should == 200

          stub1.should have_been_requested
          stub2.should have_been_requested
          stub3.should have_been_requested
        end

        it 'rejects invalid email' do
          stub = stub_request_for_template(:recovery_request,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'identification_not_recognized'
            ))
          post "/mystore/recover", :identification => 'fubar@fubar.com'
          stub.should have_been_requested
        end

        it 'rejects unverified email' do
          stub = stub_request_for_template(:recovery_request,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'email_not_verified'
            ))
          post "/mystore/recover", :identification => user_with_unverified_email.email_address
          stub.should have_been_requested
        end
      end

      ['', 'bob', 'ola normann', '+0'].each do |identification|
        it "rejects invalid identification #{identification.inspect}" do
          stub = stub_request_for_template(:recovery_request,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'identification_not_recognized'
            ))
          post "/mystore/recover", :identification => identification
          stub.should have_been_requested
        end
      end
    end
  end

  describe 'GET /:store/recover/password' do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/recover/password'
      last_response.status.should == 404
    end

    context 'when not logged in' do
      it 'renders 403' do
        checkpoint_session_identity!
        get '/mystore/recover/password'
        last_response.status.should == 403
      end
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'renders password form' do
        stub = stub_request_for_template(:recovery_password_change,
          :body => hash_including(
            :return_url => store.default_url
          ))

        get '/mystore/recover/password'
        last_response.status.should == 200

        stub.should have_been_requested
      end
    end
  end

  describe 'POST /:store/recover/password' do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/recover/password'
      last_response.status.should == 404
    end

    context 'when not logged in' do
      before :each do
        checkpoint_session_identity!
      end

      it 'renders 403' do
        post "/mystore/recover/password"
        last_response.status.should == 403
      end
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'accepts password, and logs in user' do
        post "/mystore/recover/password", {
          :password => 'newpass123',
          :password_confirmation => 'newpass123'
        }

        last_response.should be_redirect
        last_response.location.should =~ /^#{Regexp.escape(store.default_url)}/

        user.reload
        user.password_match?('newpass123').should == true
      end

      it 'requires password' do
        stub = stub_request_for_template(:recovery_password_change,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'password_required'
          ))
        post "/mystore/recover/password", {}
        stub.should have_been_requested
      end

      it 'rejects invalid password' do
        stub = stub_request_for_template(:recovery_password_change,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'password_is_too_short'
          ))
        post "/mystore/recover/password", {
          :password => 'X'
        }
        stub.should have_been_requested
      end

      it 'rejects wrong password confirmation' do
        stub = stub_request_for_template(:recovery_password_change,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'password_confirmation_mismatch'
          ))
        post "/mystore/recover/password", {
          :password => 'newpass',
          :password_confirmation => 'newpassy'
        }
        stub.should have_been_requested
      end

      it 'supports return URL' do
        post "/mystore/recover/password",
          :password => 'newpass',
          :password_confirmation => 'newpass',
          :return_url => 'http://example.com/bar'
        last_response.location.should =~ %r{^http://example\.com/bar}
      end
    end
  end

end