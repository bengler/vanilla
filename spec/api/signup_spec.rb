require 'spec_helper'

include WebMock::API
include Vanilla

describe 'Signup' do

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

  let! :user do
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

  let! :unverified_user do
    User.create!(
      :store => store,
      :name => 'Burt Engelskmann',
      :password => 'Secret123',
      :email_address => 'burt@engelskmann.com',
      :email_verified => false,
      :mobile_number => '12345678',
      :mobile_verified => false)
  end

  let :mobile_nonce do
    Nonce.create!(
      :user => unverified_user,
      :key => unverified_user.mobile_number,
      :value => '123456',
      :store => store)
  end

  let :email_nonce do
    Nonce.create!(
      :user => unverified_user,
      :key => unverified_user.email_address,
      :value => '123456',
      :store => store)
  end

  let :expired_nonce do
    Nonce.create!(
      :user => unverified_user,
      :key => unverified_user.id,
      :value => '987654',
      :store => store,
      :expires_at => Time.now - 5.minutes)
  end

  describe 'GET /:store/signup' do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/signup'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'redirects to default store URL' do
        get '/mystore/signup'
        last_response.should be_redirect
        last_response.location.should =~ /^#{Regexp.escape(store.default_url)}/
      end

      it 'redirects to provided return URL, with UID and data' do
        get '/mystore/signup', :return_url => 'http://disney.com/'
        last_response.should be_redirect
        last_response.location.should =~ %r{^http://disney\.com/}
      end
    end

    context 'when not logged in' do
      before :each do
        checkpoint_session_identity!
      end

      it 'renders "signup" template' do
        stub = stub_request_for_template(:signup,
          :body => hash_including(:return_url => store.default_url))
        get '/mystore/signup'
        stub.should have_been_requested
      end
    end

  end

  describe 'POST /:store/signup' do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      post '/fubar/signup'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'redirects to default store URL' do
        post '/mystore/signup'
        last_response.should be_redirect
        last_response.location.should =~ /^#{Regexp.escape(store.default_url)}/
      end

      it 'redirects to provided return URL' do
        post '/mystore/signup', :return_url => 'http://disney.com/'
        last_response.should be_redirect
        last_response.location.should =~ %r{^http://disney\.com/}
      end
    end

    context 'when not logged in' do
      before :each do
        checkpoint_session_identity!
      end

      it 'creates user, sends verification SMS, requests validation code' do
        stub1 = stub_request_for_template(:verification_code_sms,
          :query => hash_including(:format => 'plaintext'),
          :body => proc { |h|
            vars = JSON.parse(h)
            vars['code'].should =~ /\A[0-9]+\Z/
            vars['url'].should =~ %r{/mystore/v/}
            true
          })

        stub2 = stub_request(:post, %r{/api/hermes/v1/mystore/messages/sms}).
          with(:body => hash_including(:recipient_number => "12345678")).
          to_return(:body =>  '{"post": {"uid": "post.hermes_message:mystore$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }')

        post_body '/mystore/signup', {}, {
          :name => 'Burt Engelskmann',
          :email_address => 'burt@engelskmann.com',
          :mobile_number => '12345678',
          :password => 'foo123',
          :password_confirmation => 'foo123'
        }

        last_response.status.should == 302
        last_response.location.should =~ %r{/mystore/verify}

        nonce_id = params_from_url(last_response.location)[:nonce_id]
        nonce = Nonce.where(:id => nonce_id).first
        nonce.should_not == nil
        nonce.url.should =~ %r{/mystore/signup/complete}

        stub1.should have_been_requested
        stub2.should have_been_requested
      end

      it 'rejects invalid email' do
        stub = stub_request_for_template(:signup,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'invalid_email_address'
          ))
        post_body '/mystore/signup', {}, {
          :name => 'Burt Engelskmann',
          :email_address => '@.com',
          :mobile_number => '12345678',
          :password => 'foo123',
          :password_confirmation => 'foo123'
        }

        last_response.status.should == 400
      end

      it 'rejects invalid mobile' do
        stub = stub_request_for_template(:signup,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'invalid_mobile_number'
          ))
        post_body '/mystore/signup', {}, {
          :name => 'Burt Engelskmann',
          :email_address => 'burt@engelskmann.com',
          :mobile_number => 'xyz',
          :password => 'foo123',
          :password_confirmation => 'foo123'
        }

        last_response.status.should == 400
      end

      it 'requires mobile' do
        stub = stub_request_for_template(:signup,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'mobile_number_required'
          ))
        post_body '/mystore/signup', {}, {
          :name => 'Burt Engelskmann',
          :email_address => 'burt@engelskmann.com',
          :password => 'foo123',
          :password_confirmation => 'foo123'
        }

        last_response.status.should == 400
      end

      it 'rejects non-unique email address' do
        stub = stub_request_for_template(:signup,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'email_address_in_use'
          ))
        post_body '/mystore/signup', {}, {
          :name => 'Burt Engelskmann',
          :email_address => user.email_address,
          :mobile_number => '12345678',
          :password => 'foo123',
          :password_confirmation => 'foo123'
        }

        last_response.status.should == 400
      end

      ['', "\t", "\t  ", '       '].each do |bad_name|
        it "rejects empty user name #{bad_name.inspect}" do
          stub = stub_request_for_template(:signup,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'name_required'
            ))
          post_body '/mystore/signup', {}, {
            :name => bad_name,
            :email_address => 'burt@engelskmann.com',
            :mobile_number => '12345678',
            :password => 'foo123',
            :password_confirmation => 'foo123'
          }

          last_response.status.should == 400
        end
      end

      ['b', '-', '?'].each do |bad_name|
        # TODO: Do more careful tests that check store's name requirements
        it "rejects bad user name #{bad_name.inspect}" do
          stub = stub_request_for_template(:signup,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'name_is_too_short'
            ))
          post_body '/mystore/signup', {}, {
            :name => bad_name,
            :email_address => 'burt@engelskmann.com',
            :mobile_number => '12345678',
            :password => 'foo123',
            :password_confirmation => 'foo123'
          }

          last_response.status.should == 400
        end
      end

      it 'rejects wrong password confirmation' do
        stub = stub_request_for_template(:signup,
          :body => hash_including(
            :return_url => store.default_url,
            :error => 'password_confirmation_mismatch'
          ))
        post_body '/mystore/signup', {}, {
          :name => 'Burt Engelskmann',
          :email_address => 'burt@engelskmann.com',
          :mobile_number => '12345678',
          :password => 'foo123',
          :password_confirmation => 'foo12'
        }

        last_response.status.should == 400
      end

      %w(foo fo12 123).each do |bad_password|
        # TODO: Do more careful tests that check store's password requirements
        it "rejects bad password #{bad_password.inspect}" do
          stub = stub_request_for_template(:signup,
            :body => hash_including(
              :return_url => store.default_url,
              :error => 'password_is_too_short'
            ))
          post_body '/mystore/signup', {}, {
            :name => 'Burt Engelskmann',
            :email_address => 'burt@engelskmann.com',
            :mobile_number => '12345678',
            :password => bad_password,
            :password_confirmation => bad_password
          }

          last_response.status.should == 400
        end
      end
    end

    context 'when not logged in and user already exists' do
      before :each do
        checkpoint_session_identity!
      end

      it 'logs in user if mobile and password matches' do
        post_body '/mystore/signup', {}, {
          :name => 'Ola Nordmann',
          :email_address => 'ola@nordmann.com',
          :mobile_number => '10001',
          :password => 'Secret123',
          :password_confirmation => 'Secret123'
        }

        last_response.should be_redirect
        last_response.location.should =~ /^#{Regexp.escape(store.default_url)}/

        transitional_user.should == user
      end

      it 'logs in user if mobile and at least one password matches' do
        post_body '/mystore/signup', {}, {
          :name => 'Ola Nordmann',
          :email_address => 'ola@nordmann.com',
          :mobile_number => '10001',
          :password => 'Secret123',
          :password_confirmation => 'WRONGSECRET'
        }
        last_response.should be_redirect
        transitional_user.should == user
      end

      context "if mobile matches but password mismatches" do
        [
          {:description => 'name matches, email matches', :matches => [:mobile_number, :name, :email_address]},
          {:description => 'name matches, email mismatches', :matches => [:mobile_number, :name]},
          {:description => 'name mismatches, email matches', :matches => [:mobile_number, :email_address]},
        ].each do |example|
          it "renders duplicate signup template when #{example[:description]}" do
            if example[:matches].include?(:name)
              name = user.name
            else
              name = "John Doe"
            end
            if example[:matches].include?(:email_address)
              email = user.email_address
            else
              email = "walt@disney.com"
            end
            stub = stub_request_for_template(:duplicate_signup,
              :body => hash_including(
                :name => name,
                :mobile_number => user.mobile_number,
                :email_address => email,
                :matches => example[:matches].map(&:to_s).sort.join(',')))

            post_body '/mystore/signup', {}, {
              :name => name,
              :email_address => email,
              :mobile_number => user.mobile_number,
              :password => 'WRONG',
              :password_confirmation => 'STILLWRONG'
            }

            last_response.status.should == 400

            stub.should have_been_requested
          end
        end
      end
    end

  end

  describe 'GET /:store/signup/complete' do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/signup/complete'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        unverified_user.activate!
        checkpoint_session_identity!(unverified_user)
      end

      it 'sends email verification code, returns' do
        email_template_stub = stub_request_for_template(:verification_code_email,
          :query => hash_including(:format => 'json'),
          :body => proc { |h|
            vars = JSON.parse(h)
            vars['code'].should =~ /\A[0-9a-z]+\Z/
            vars['url'].should =~ %r{/mystore/v/}
            true
          }).
          to_return(:body => JSON.dump({
            "from" => store.default_sender_email_address,
            "subject" => "A code, my kingdom for a code",
            "text" => "Code is 1234",
            "html" => "<p>Code is 1234</p>",
            "to" => "burt@engelskmann.com"
          }))

        hermes_stub = stub_request(:post, "http://example.org/api/hermes/v1/mystore/messages/email").
          with(:body => "{\"sender_email\":\"Example <notifications@example.com>\",\"recipient_email\":\"burt@engelskmann.com\",\"subject\":\"A code, my kingdom for a code\",\"html\":\"<p>Code is 1234</p>\",\"text\":\"Code is 1234\",\"path\":\"vanilla\",\"session\":\"god\"}",
               :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json'}).
          to_return(:status => 200, :body => '{"post": {"uid": "post.hermes_message:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }', :headers => {})

        get "/mystore/signup/complete"
        last_response.should be_redirect
        last_response.location.should =~ /^#{Regexp.escape(store.default_url)}/

        unverified_user.reload
        unverified_user.email_verified?.should == false

        hermes_stub.should have_been_requested
        email_template_stub.should have_been_requested
      end
    end

    context 'when logged in as unactivated user' do
      before :each do
        checkpoint_session_identity!(unverified_user)
      end

      it 'renders 403' do
        get "/mystore/signup/complete"
        last_response.status.should == 403
      end
    end

    context 'when not logged in' do
      before :each do
        checkpoint_session_identity!
      end

      it 'renders 403' do
        get "/mystore/signup/complete"
        last_response.status.should == 403
      end
    end
  
  end

end