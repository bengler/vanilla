require 'spec_helper'

include WebMock::API
include Vanilla

describe 'Stores' do

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

  describe "GET /stores" do

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'returns stores' do
        get "/stores"
        last_response.status.should == 200
        data = JSON.parse(last_response.body)
        data.should include('stores')
        data['stores'].length.should == 1
        data['stores'][0].should include('store')
        data['stores'][0]['store'].should include('created_at')
        data['stores'][0]['store'].should include('updated_at')
        %w(
          name
          default_url
          template_url
          scopes
          user_name_pattern
          minimum_user_name_length
          maximum_user_name_length
          default_sender_email_address
          hermes_session
        ).each do |attr|
          data['stores'][0]['store'][attr].to_s.should == store.send(attr).to_s
        end
      end

    end
  end

  describe "GET /stores/:name" do

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'renders 404 if non-existent store' do
        get "/stores/fubar"
        last_response.status.should == 404
      end

      it 'renders store' do
        get "/stores/mystore"
        last_response.status.should == 200
        data = JSON.parse(last_response.body)
        data.should include('store')
        data['store'].should include('created_at')
        data['store'].should include('updated_at')
        %w(
          name
          default_url
          template_url
          scopes
          user_name_pattern
          minimum_user_name_length
          maximum_user_name_length
          default_sender_email_address
          hermes_session
        ).each do |attr|
          data['store'][attr].to_s.should == store.send(attr).to_s
        end
      end

    end
  end

  describe "PUT /stores" do

    context 'when not god' do
      before :each do
        checkpoint_session_identity!
      end

      it 'fails with 403' do
        put "/stores", {:name => 'newstore'}
        last_response.status.should == 403
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'creates store via params' do
        put "/stores", {
          :name => 'newstore',
          :template_url => 'http://example.com/template',
          :default_url => 'http://example.com/',
          :scopes => {
            'basic' => 'Just basic stuff',
            'extended' => 'Bags of stuff'
          }
        }
        last_response.status.should == 201
        last_response.location.should =~ %r{/stores/newstore}
        Store.where(:name => 'newstore').first.should_not == nil
      end

      it 'creates store via JSON' do
        put_body '/stores', {}, {
          :name => 'newstore',
          :template_url => 'http://example.com/template',
          :default_url => 'http://example.com/',
          :scopes => {
            'basic' => 'Just basic stuff',
            'extended' => 'Bags of stuff'
          }
        }
        last_response.status.should == 201
        last_response.location.should =~ %r{/stores/newstore}
        Store.where(:name => 'newstore').first.should_not == nil
      end

    end
  end

  describe "POST /stores/:name" do

    context 'when not god' do
      before :each do
        checkpoint_session_identity!
      end

      it 'fails with 403' do
        post "/stores/mystore", {:template_url => 'http://example.com/templates'}
        last_response.status.should == 403
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'creates store via params' do
        post "/stores/mystore", {:template_url => 'http://example.com/templates'}
        last_response.status.should == 200
        store.reload
        store.template_url.should == 'http://example.com/templates'
      end

      it 'creates store via JSON' do
        post_body '/stores/mystore', {}, {
          :template_url => 'http://example.com/templates',
        }
        last_response.status.should == 200
        store.reload
        store.template_url.should == 'http://example.com/templates'
      end
    end

  end

end