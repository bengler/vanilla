require 'spec_helper'

include Vanilla

describe Client do

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

  describe '#merge_oauth_redirect_url' do
    it 'rejects URL with different host' do
      lambda {
        client.merge_oauth_redirect_url('http://example.org/oauth')
      }.should raise_error(Client::InvalidRedirectUrl)
    end

    it 'rejects URL with different port' do
      lambda {
        client.merge_oauth_redirect_url('http://example.com:8080/oauth')
      }.should raise_error(Client::InvalidRedirectUrl)
    end

    it 'rejects URL with different port and HTTPS instead of HTTP' do
      lambda {
        client.merge_oauth_redirect_url('https://example.com:8080/oauth')
      }.should raise_error(Client::InvalidRedirectUrl)
    end

    it 'rejects URL with different port and HTTP instead of HTTPS' do
      lambda {
        client.oauth_redirect_uri = 'https://example.com/oauth'
        client.merge_oauth_redirect_url('http://example.com:8080/oauth')
      }.should raise_error(Client::InvalidRedirectUrl)
    end

    it 'accepts URL with same port, but HTTPS instead of HTTP' do
      lambda {
        client.merge_oauth_redirect_url('https://example.com/oauth')
      }.should_not raise_error(Client::InvalidRedirectUrl)
    end

    it 'accepts URL with same port, HTTP instead of HTTPS' do
      lambda {
        client.oauth_redirect_uri = 'https://example.com/oauth'
        client.merge_oauth_redirect_url('http://example.com/oauth')
      }.should_not raise_error(Client::InvalidRedirectUrl)
    end

    it 'joins empty query strings' do
      merged = client.merge_oauth_redirect_url('http://example.com/oauth')
      merged.should == 'http://example.com/oauth'
    end

    it 'joins query string client URI with no query string' do
      merged = client.merge_oauth_redirect_url(
        'http://example.com/oauth', :bar => '2')
      merged.should =~ %r{^http://example.com/oauth\?}
      params = params_from_url(merged)
      params.keys.should == ['bar']
      params['bar'].should == '2'
    end

    it 'merges two query strings' do
      merged = client.merge_oauth_redirect_url(
        'http://example.com/oauth?foo=1&bar=2', :bar => '3', :a => 'b')
      merged.should =~ %r{^http://example.com/oauth\?}
      params = params_from_url(merged)
      params.keys.sort.should == ['a', 'bar', 'foo']
      params['foo'].should == '1'
      params['bar'].should == '3'
      params['a'].should == 'b'
    end
  end

end