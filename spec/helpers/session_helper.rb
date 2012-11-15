module SessionHelper

  def checkpoint_session_key_cookie!
    rack_mock_session.cookie_jar['checkpoint.session'] = current_fake_session_key
  end

  def current_fake_session_key
    @current_fake_session_key ||= rand(2 ** 512).to_s(36)
  end

  def session_hash
    (decode_cookie(rack_mock_session.cookie_jar['vanilla.session']) || {}).
      with_indifferent_access
  end

  def update_session_hash(hash)
    rack_mock_session.cookie_jar['vanilla.session'] = encode_cookie({
      'session_id' => rand(100000).to_s
    }.merge(hash))
  end

  def transitional_user
    if (info = session_hash[:transitional_user])
      if info['session_key'] == current_fake_session_key
        User.where(:id => info['user_id']).first
      end
    end
  end

  def transitional_user!(user)
    update_session_hash(:transitional_user => {
      'user_id' => user.id,
      'session_key' => current_fake_session_key
    })
  end

  def checkpoint_session_identity!(user = nil, options = {})
    if user
      user.logged_in = true
      user.save(:validate => false)

      identity_id = user.id + 1000

      stub_request(:get, %r{/api/checkpoint/v1/identities/me}).
        to_return(:status => 200, :body => JSON.dump({
          :identity => {
            :id => identity_id,
            :god => options[:god] || false,
            :realm => options[:realm] || user.store.name
          }
        }))

      stub_request(:get, %r{/api/checkpoint/v1/identities/#{identity_id}/accounts/vanilla}).
        to_return(:status => 200, :body => JSON.dump({
          :account => {
            :uid => user.id,
            :provider => 'vanilla'
          }
        }))
    else
      stub_request(:get, %r{/api/checkpoint/v1/identities/me}).
        to_return(:status => 200, :body => '{}')
    end
  end

  def stub_request_for_template(template_name, stub_options = {})
    return stub_request(:post, 'http://example.com/template').with({
      :query => hash_including(:template => template_name.to_s),
      :headers => {
        'Content-Type' => 'application/json'
      }
    }.merge(stub_options))
  end

  private

    def encode_cookie(value)
      [Marshal.dump(value)].pack('m')
    end

    def decode_cookie(cookie)
      Marshal.load(cookie.unpack('m').first) if cookie
    end

end