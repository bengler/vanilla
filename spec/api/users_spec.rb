require 'spec_helper'

include WebMock::API
include Vanilla

describe 'Users' do

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

  let :other_store do
    Store.create!(
      :name => 'otherstore',
      :template_url => 'http://example.org/template',
      :default_url => 'http://example.org/',
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

  let! :unactivated_user do
    User.create!(
      :store => store,
      :name => 'Bob Nordmann',
      :password => 'Secret123',
      :email_address => 'bob@nordmann.com',
      :email_verified => true,
      :mobile_number => '10002',
      :mobile_verified => true)
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

  describe "GET /:store/users/:id" do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      get "/fubar/users/#{user.id}"
      last_response.status.should == 404
    end

    it 'renders 404 if non-existent user' do
      checkpoint_session_identity!
      get "/mystore/users/1393298932"
      last_response.status.should == 404
    end

    it 'renders 404 if user is in different store' do
      checkpoint_session_identity!
      get "/otherstore/users/#{user.id}"
      last_response.status.should == 404
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'renders user' do
        get "/mystore/users/#{user.id}"
        last_response.status.should == 200
        data = JSON.parse(last_response.body)
        data.should include('user')
        %w(id name email_address email_verified mobile_number mobile_verified
          activated activated_at).each do |attr|
          case attr
            when 'activated_at'
              Time.parse(data['user'][attr]).iso8601.should == user.send(attr).iso8601
            else
              data['user'][attr].should == user.send(attr)
          end
        end
        data['user']['store'].should == store.name
      end
    end

    context 'when not god' do
      before :each do
        checkpoint_session_identity!(user)
      end

      it 'returns 403 when not current user' do
        get "/mystore/users/#{god_user.id}"
        last_response.status.should == 403
      end

      it 'renders user if same as current' do
        get "/mystore/users/#{user.id}"
        last_response.status.should == 200
      end
    end
  end

  describe "POST /:store/users" do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      post "/fubar/users"
      last_response.status.should == 404
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'creates user via params' do
        post "/mystore/users", {
          :name => "Kari Nordmann",
          :mobile_number => '12345678'
        }
        last_response.status.should == 201
        last_response.location.should =~ %r{/mystore/users/(\d+)$}
        user = User.find($1) if last_response.location =~ %r{/mystore/users/(\d+)$}
        user.should_not == nil
        user.name.should == 'Kari Nordmann'
        user.activated_at.should_not == nil
        user.activated.should == true
      end

      it 'creates user via JSON' do
        post_body '/mystore/users', {}, {
          :name => 'Kari Nordmann',
          :mobile_number => '12345678'
        }
        last_response.status.should == 201
        last_response.location.should =~ %r{/mystore/users/(\d+)$}
        user = User.find($1) if last_response.location =~ %r{/mystore/users/(\d+)$}
        user.should_not == nil
        user.name.should == 'Kari Nordmann'
        user.activated_at.should_not == nil
        user.activated.should == true
      end

      it 'allows blank mobile number' do
        post_body '/mystore/users', {}, {
          :name => 'Kari Nordmann'
        }
        last_response.status.should == 201
        last_response.location.should =~ %r{/mystore/users/(\d+)$}
        user = User.find($1) if last_response.location =~ %r{/mystore/users/(\d+)$}
        user.should_not == nil
        user.name.should == 'Kari Nordmann'
        user.activated_at.should_not == nil
        user.activated.should == true
      end

      it 'returns 409 if mobile number is in use' do
        post_body '/mystore/users', {}, {
          name: 'Kari Nordmann',
          mobile_number: '10001'
        }
        last_response.status.should == 409
        last_response.headers['Error'].should eq 'mobile_number_in_use'
      end

      it 'returns 409 if email is in use' do
        post_body '/mystore/users', {}, {
          name: 'Kari Nordmann',
          email_address: 'ola@nordmann.com'
        }
        last_response.status.should == 409
        last_response.headers['Error'].should eq 'email_address_in_use'
      end

      it 'rejects invalid user data' do
        post "/mystore/users", {:name => "Kari"}
        last_response.status.should == 400
      end

      it 'supports setting password hash' do    
        hash = BCrypt::Password.create("dingleberries")
        post "/mystore/users", {
          :name => 'Kari Nordmann',
          :mobile_number => '12345678',
          :password_hash => hash
        }
        last_response.status.should == 201
        user = User.find($1) if last_response.location =~ %r{/mystore/users/(\d+)$}
        user.password_match?('dingleberries').should == true
      end

      it 'supports setting legacy password hash' do
        hash = 'legacy:d2612cedd40444f8df98cedf952c4485f4a40e86'
        post "/mystore/users", {
          :name => 'Kari Nordmann',
          :mobile_number => '12345678',
          :password_hash => hash
        }
        last_response.status.should == 201
        user = User.find($1) if last_response.location =~ %r{/mystore/users/(\d+)$}
        user.password_match?('dingleberries').should == true
      end
    end

    context 'when god in other store' do
      before :each do
        checkpoint_session_identity!(god_user, :realm => 'other', :god => true)
      end

      it 'returns 403' do
        post "/mystore/users", {:name => "Kari Nordmann"}
        last_response.status.should == 403
      end
    end

  end

  describe "PUT /:store/users/:id" do

    it 'renders 404 if non-existent store' do
      checkpoint_session_identity!
      put "/fubar/users/#{user.id}"
      last_response.status.should == 404
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'updates user via params' do
        put "/mystore/users/#{user.id}", {
          :name => "Ola X. Nordmann"
        }
        last_response.status.should == 200
        user.reload
        user.name.should == 'Ola X. Nordmann'
      end

      it 'updates user via JSON' do
        put_body "/mystore/users/#{user.id}", {}, {
          :name => "Ola X. Nordmann"
        }
        last_response.status.should == 200
        user.reload
        user.name.should == 'Ola X. Nordmann'
      end

      it 'returns 409 if mobile number is in use' do
        existing_user = User.create!(
          store: store,
          name: 'Borghild Nordmann',
          password: 'Secret123',
          mobile_number: '10002',
          mobile_verified: true,
          activated: true)
        put_body "/mystore/users/#{user.id}", {}, {
          mobile_number: '10002'
        }
        last_response.status.should == 409
        last_response.headers['Error'].should eq 'mobile_number_in_use'
      end

      it 'returns 409 if email is in use' do
        existing_user = User.create!(
          store: store,
          name: 'Borghild Nordmann',
          password: 'Secret123',
          email_address: 'borghild@nordmann.com',
          email_verified: true,
          activated: true)
        put_body "/mystore/users/#{user.id}", {}, {
          email_address: 'borghild@nordmann.com'
        }
        last_response.status.should == 409
        last_response.headers['Error'].should eq 'email_address_in_use'
      end

      it 'rejects invalid user' do
        put "/mystore/users/#{user.id}", {
          :name => "Ola"
        }
        last_response.status.should == 400
      end

      %w(mobile_verified email_verified password_hash activated activated_at).each do |attr|
        it "allows update of '#{attr}'" do
          attrs = {
            :name => "Kari Nordmann",
            :mobile_number => '12345678'
          }
          case attr
            when 'password_hash'
              attrs[attr] = 'xyz'
            when 'activated_at'
              attrs[attr] = Time.now.iso8601
            else
              attrs[attr] = true
          end
          put "/mystore/users/#{user.id}", attrs
          last_response.status.should == 200
        end

        it 'supports setting password hash' do
          put "/mystore/users/#{user.id}", {
            :password_hash => BCrypt::Password.create('dingleberries')
          }
          last_response.status.should == 200
          user.reload
          user.password_match?('dingleberries').should == true
        end

        it 'supports setting legacy password hash' do
          put "/mystore/users/#{user.id}", {
            :password_hash => 'legacy:d2612cedd40444f8df98cedf952c4485f4a40e86'
          }
          last_response.status.should == 200
          user.reload
          user.password_match?('dingleberries').should == true
        end
      end
    end

    context 'when not god' do
      before :each do
        checkpoint_session_identity!(user)
      end

      %w(mobile_verified email_verified password_hash activated activated_at).each do |attr|
        it "prohibits from updating '#{attr}'" do
          attrs = {
            :name => "Kari Nordmann",
            :mobile_number => '12345678'
          }
          case attr
            when 'password_hash'
              attrs[attr] = 'xyz'
            when 'activated_at'
              attrs[attr] = Time.now.iso8601
            else
              attrs[attr] = true
          end
          put "/mystore/users/#{user.id}", attrs
          last_response.status.should == 403
        end
      end
    end

    context 'when god in other store' do
      before :each do
        checkpoint_session_identity!(god_user, :realm => 'other', :god => true)
      end

      it "prohibits god in other store from updating user" do
        put "/mystore/users/#{user.id}", :mobile_number => '12345678'
        last_response.status.should == 403
      end
    end

  end

  describe 'GET /:store/users/find' do

    context 'when not god' do
      before :each do
        checkpoint_session_identity!
      end

      it 'returns 403' do
        get "/mystore/users/find", {:mobile_number => user.mobile_number}
        last_response.status.should == 403
      end
    end

    context 'when god' do
      before :each do
        checkpoint_session_identity!(god_user, :god => true)
      end

      it 'finds nothing when no criteria are specified' do
        get "/mystore/users/find"
        last_response.status.should == 200
        data = JSON.parse(last_response.body)
        data.should include('users')
        data['users'].length.should == 0
      end

      %w(name mobile_number email_address).each do |attr|
        it "finds users by #{attr}" do
          get "/mystore/users/find", {attr => user.send(attr)}
          last_response.status.should == 200
          data = JSON.parse(last_response.body)
          data.should include('users')
          data['users'].length.should == 1
          data['users'][0]['id'].should == user.id
        end
      end
    end

  end

end