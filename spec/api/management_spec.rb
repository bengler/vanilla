require 'spec_helper'

include WebMock::API
include Vanilla

describe 'Management' do

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

  let :other_user do
    User.create!(
      :store => store,
      :name => 'Kari Nordmann',
      :password => 'Secret123',
      :email_address => 'kari@nordmann.com',
      :email_verified => true,
      :mobile_number => '10002',
      :mobile_verified => true,
      :activated => true,
      :activated_at => Time.now)
  end

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

  describe "GET /:store/users/:id/edit" do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/auth'
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent user' do
      checkpoint_session_identity!
      get '/mystore/users/99999/edit'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'renders editing template' do
        stub = stub_request_for_template(:edit_user)
        get "/mystore/users/#{user.id}/edit"
        last_response.status.should == 200
        stub.should have_been_requested
      end

      it 'rejects if user is not the current user' do
        get "/mystore/users/#{other_user.id}/edit"
        last_response.status.should == 403
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'renders editing template for any user' do
        stub = stub_request_for_template(:edit_user)
        get "/mystore/users/#{user.id}/edit"
        last_response.status.should == 200
        stub.should have_been_requested
      end
    end
  end

  describe "POST /:store/users/:id/edit" do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      post '/fubar/auth'
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent user' do
      checkpoint_session_identity!
      post '/mystore/users/99999/edit'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'updates password' do
        post "/mystore/users/#{user.id}/edit", {
          :password => 'mysecret99',
          :password_confirmation => 'mysecret99',
          :current_password => 'Secret123'
        }
        last_response.status.should == 302
        user.reload
        user.password_match?('mysecret99').should == true
      end

      it 'requires current password' do
        stub = stub_request_for_template(:edit_user).
          with(:body => hash_including(:error => 'password_required'))
        post "/mystore/users/#{user.id}/edit", {
          :password => 'mysecret99',
          :password_confirmation => 'mysecret99'
        }
        last_response.status.should == 400
        user.reload
        user.password_match?('Secret123').should == true
      end

      it 'rejects if user is not the current user' do
        stub = stub_request_for_template(:edit_user)
        post "/mystore/users/#{other_user.id}/edit", {
          :password => 'mysecret99',
          :password_confirmation => 'mysecret99',
          :current_password => 'Secret123'          
        }
        last_response.status.should == 403
        stub.should_not have_been_requested        
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'updates password' do
        post "/mystore/users/#{user.id}/edit", {
          :password => 'mysecret99',
          :password_confirmation => 'mysecret99',    
          :current_password => 'Secret123'      
        }
        last_response.status.should == 302
        user.reload
        user.password_match?('mysecret99').should == true
      end

      it 'updates password without having to supply current password' do
        post "/mystore/users/#{user.id}/edit", {
          :password => 'mysecret99',
          :password_confirmation => 'mysecret99'
        }
        last_response.status.should == 302
        user.reload
        user.password_match?('mysecret99').should == true
      end
    end
  end

  describe "GET /:store/users/:id/mobile" do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/auth'
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent user' do
      checkpoint_session_identity!
      get '/mystore/users/99999/mobile'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'renders editing template' do
        stub = stub_request_for_template(:change_mobile)
        get "/mystore/users/#{user.id}/mobile"
        last_response.status.should == 200
        stub.should have_been_requested
      end

      it 'rejects if user is not the current user' do
        get "/mystore/users/#{other_user.id}/mobile"
        last_response.status.should == 403
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'renders editing template for any user' do
        stub = stub_request_for_template(:change_mobile)
        get "/mystore/users/#{user.id}/mobile"
        last_response.status.should == 200
        stub.should have_been_requested
      end
    end
  end

  describe "POST /:store/users/:id/mobile" do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      post '/fubar/auth'
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent user' do
      checkpoint_session_identity!
      post '/mystore/users/99999/mobile'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'updates mobile number and sends verification SMS' do
        stub_request_for_template(:verification_code_sms,
          :query => hash_including(:format => 'plaintext'),
          :body => proc { |h|
            vars = JSON.parse(h)
            vars['code'].should =~ /\A[0-9]+\Z/
            vars['url'].should =~ %r{/mystore/v/}
            true
          })

        stub_request(:post, %r{/api/hermes/v1/mystore/messages/sms}).
          with(:body => hash_including(:recipient_number => '202020')).
          to_return(:body =>  '{"post": {"uid": "post.hermes_message:mystore$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }')

        post "/mystore/users/#{user.id}/mobile", {
          :mobile_number => '202020'
        }
        last_response.status.should == 302
        last_response.location.should =~ %r{/mystore/verify}
        user.reload
        user.mobile_number.should == '202020'
        user.mobile_verified.should == false
      end

      it "requires mobile number" do
        stub = stub_request_for_template(:change_mobile).
          with(:body => hash_including(:error => 'mobile_number_required'))
        post "/mystore/users/#{user.id}/mobile", {
          :mobile_number => ''
        }
        last_response.status.should == 400
        user.reload
        user.mobile_number.should == '10001'
        user.mobile_verified.should == true
      end

      ['+', '0'].each do |number|
        it "rejects invalid mobile number '#{number}'" do
          stub = stub_request_for_template(:change_mobile).
            with(:body => hash_including(:error => 'invalid_mobile_number'))
          post "/mystore/users/#{user.id}/mobile", {
            :mobile_number => number
          }
          last_response.status.should == 400
          user.reload
          user.mobile_number.should == '10001'
          user.mobile_verified.should == true
        end
      end

      it 'rejects if user is not the current user' do
        stub = stub_request_for_template(:edit_user)
        post "/mystore/users/#{other_user.id}/mobile", {
          :mobile_number => '202020'
        }
        last_response.status.should == 403
        stub.should_not have_been_requested
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'updates mobile number and sets it as verified' do
        post "/mystore/users/#{user.id}/mobile", {
          :mobile_number => '202020'
        }
        last_response.status.should == 302
        user.reload
        user.mobile_number.should == '202020'
        user.mobile_verified.should == true
      end
    end
  end

  describe "GET /:store/users/:id/email" do
    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get '/fubar/auth'
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent user' do
      checkpoint_session_identity!
      get '/mystore/users/99999/email'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'renders editing template' do
        stub = stub_request_for_template(:change_email)
        get "/mystore/users/#{user.id}/email"
        last_response.status.should == 200
        stub.should have_been_requested
      end

      it 'rejects if user is not the current user' do
        get "/mystore/users/#{other_user.id}/email"
        last_response.status.should == 403
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'renders editing template for any user' do
        stub = stub_request_for_template(:change_email)
        get "/mystore/users/#{user.id}/email"
        last_response.status.should == 200
        stub.should have_been_requested
      end
    end

  end

  describe "POST /:store/users/:id/email" do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      post '/fubar/auth'
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent user' do
      checkpoint_session_identity!
      post '/mystore/users/99999/email'
      last_response.status.should == 404
    end

    context 'when logged in' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'updates email address and sends verification email' do
        stub = stub_request_for_template(:verification_code_email,
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

        stub_request(:post, "http://vanilla.dev/api/hermes/v1/mystore/messages/email").
          with(:body => "{\"sender_email\":\"Example <notifications@example.com>\",\"recipient_email\":\"bob@example.com\",\"subject\":\"A code, my kingdom for a code\",\"text\":\"Code, blah blah\",\"path\":\"vanilla\",\"session\":\"god\"}",
               :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json'}).
          to_return(:status => 200, :body =>  '{"post": {"uid": "post.hermes_message:test$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["in_progress"] }', :headers => {})

        stub = stub_request_for_template(:verification_code_sent,
          :body => proc { |h|
            vars = JSON.parse(h)
            vars['context'].should == 'change'
            vars['endpoint'].should == 'email'
            vars['delivery_status_key'].to_s.should == ''
            true
          })

        post "/mystore/users/#{user.id}/email", {
          :email_address => 'bob@example.com'
        }
        last_response.status.should == 200
        user.reload
        user.email_address.should == 'bob@example.com'
        user.email_verified.should == false
      end

      it 'requires email address' do
        stub = stub_request_for_template(:change_email).
          with(:body => hash_including(:error => 'email_address_required'))
        post "/mystore/users/#{user.id}/email", {
          :email_address => ''
        }
        last_response.status.should == 400
        user.reload
        user.email_address.should == 'ola@nordmann.com'
        user.email_verified.should == true
      end

      ['@', '.', 'foo'].each do |email|
        it "rejects invalid email '#{email}'" do
          stub = stub_request_for_template(:change_email).
            with(:body => hash_including(:error => 'invalid_email_address'))
          post "/mystore/users/#{user.id}/email", {
            :email_address => email
          }
          last_response.status.should == 400
          user.reload
          user.email_address.should == 'ola@nordmann.com'
          user.email_verified.should == true
        end
      end

      it 'rejects if user is not the current user' do
        stub = stub_request_for_template(:edit_user)
        post "/mystore/users/#{other_user.id}/email", {
          :email_address => 'bob@example.com'
        }
        last_response.status.should == 403
        stub.should_not have_been_requested
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'updates email address and sets it as verified' do
        post "/mystore/users/#{user.id}/email", {
          :email_address => 'bob@example.com'
        }
        last_response.status.should == 302
        user.reload
        user.email_address.should == 'bob@example.com'
        user.email_verified.should == true
      end
    end

  end

end