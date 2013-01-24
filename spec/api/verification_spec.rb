require 'spec_helper'

include WebMock::API
include Vanilla

describe 'Verification' do

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

  let! :unverified_user do
    User.create!(
      :store => store,
      :name => 'Ola Nordmann',
      :password => 'Secret123',
      :email_address => 'ola@nordmann.com',
      :email_verified => false,
      :mobile_number => '10001',
      :mobile_verified => false)
  end

  let :mobile_nonce do
    Nonce.create!(
      :user => unverified_user,
      :key => unverified_user.mobile_number,
      :value => '123456',
      :url => 'http://example.com',
      :store => store,
      :context => :signup,
      :endpoint => :mobile,
      :delivery_status_key => '666')
  end

  let :email_nonce do
    Nonce.create!(
      :user => unverified_user,
      :key => unverified_user.email_address,
      :value => '123456',
      :url => 'http://example.com',
      :store => store,
      :context => :signup,
      :endpoint => :email,
      :delivery_status_key => '666')
  end

  before :each do
    checkpoint_session_identity!
  end

  describe 'GET /:store/verify' do
    it 'renders 404 if non-existent store' do
      get '/fubar/verify'
      last_response.status.should == 404
    end

    it 'renders verification form if no code provided' do
      stub = stub_request_for_template(:verification_code_validation,
        :body => hash_including(
          :return_url => mobile_nonce.url,
          :context => 'signup',
          :endpoint => 'mobile'
        ))

      get '/mystore/verify', :nonce_id => mobile_nonce.id
      last_response.status.should == 200

      stub.should have_been_requested
    end

    it 'verifies the code if code is provided' do
      get '/mystore/verify', :nonce_id => mobile_nonce.id, :code => mobile_nonce.value
      last_response.status.should == 302
      last_response.location.should == mobile_nonce.url
      unverified_user.reload
      unverified_user.mobile_verified.should == true
    end

    it 'rejects invalid code' do
      stub = stub_request_for_template(:verification_code_validation,
        :body => hash_including(
          :return_url => mobile_nonce.url,
          :context => 'signup',
          :endpoint => 'mobile',
          :error => 'invalid_code'
        ))
      get '/mystore/verify', :nonce_id => mobile_nonce.id, :code => "92929"
      unverified_user.reload
      unverified_user.mobile_verified.should == false
    end
  end

  describe 'POST /:store/verify' do
    it 'verifies code' do
      post '/mystore/verify', :nonce_id => mobile_nonce.id, :code => mobile_nonce.value
      last_response.status.should == 302
      last_response.location.should == mobile_nonce.url

      unverified_user.reload
      unverified_user.mobile_verified.should == true

      mobile_nonce.reload
      mobile_nonce.expired?.should == true
    end

    it 'rejects invalid code' do
      stub = stub_request_for_template(:verification_code_validation,
        :body => hash_including(
          :return_url => mobile_nonce.url,
          :context => 'signup',
          :endpoint => 'mobile',
          :error => 'invalid_code'
        ))
      post '/mystore/verify', :nonce_id => mobile_nonce.id, :code => "92929"
      last_response.status.should == 403
      unverified_user.reload
      unverified_user.mobile_verified.should == false
    end

    it 'rejects expired nonce' do
      mobile_nonce.expires_at = Time.now - 5.minutes
      mobile_nonce.save!

      stub = stub_request_for_template(:verification_code_validation,
        :body => hash_including(
          :return_url => mobile_nonce.url,
          :context => 'signup',
          :endpoint => 'mobile',
          :error => 'expired_code'
        ))
      post '/mystore/verify', :nonce_id => mobile_nonce.id, :code => mobile_nonce.value
      last_response.status.should == 403
      unverified_user.reload
      unverified_user.mobile_verified.should == false
    end
  end

  describe 'GET /:store/delivery_status/:id' do
    it 'renders 404 if non-existent store' do
      get '/fubar/delivery_status/666'
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent ID' do
      stub = stub_request(:get, "http://localhost/api/hermes/v1/mystore/messages/post.hermes_message:example$1234?session=god").
        to_return(:status => 404)
      get "/mystore/delivery_status/post.hermes_message:example$1234"
      last_response.status.should == 404
    end

    it 'returns status' do
      stub = stub_request(:get, "http://localhost/api/hermes/v1/mystore/messages/post.hermes_message:example$1234?session=god").
        to_return(:body =>  '{"post": {"uid": "post.hermes_message:mystore$1234", "document": {"body": "fofo", "callback_url": "http://example.com/"}}, "tags": ["inprogress", "delivered"] }')
      get "/mystore/delivery_status/post.hermes_message:example$1234"
      stub.should have_been_requested
      JSON.parse(last_response.body)['status'].should eq ["inprogress", "delivered"]
    end
  end

end