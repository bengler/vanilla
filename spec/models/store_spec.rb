require 'spec_helper'

include Vanilla

describe Store do

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

  describe '#default_scope' do
    it 'returns a random scope' do
      %w(basic extended).should include(store.default_scope)
    end
  end

  describe '#parse_scopes' do
    it 'returns default scope if the string has no scopes' do
      store.parse_scopes('').should == [store.default_scope]
      store.parse_scopes(',').should == [store.default_scope]
      store.parse_scopes('  ').should == [store.default_scope]
    end

    it 'returns default scope if the string is an invalid scope' do
      store.parse_scopes('cheese').should == [store.default_scope]
    end

    it 'returns single scope if string contains a single scope' do
      store.parse_scopes('basic').should == ['basic']
    end

    it 'returns two scopes if string contains a tw scopes' do
      store.parse_scopes('basic,extended').sort.should == ['basic', 'extended']
    end

    it 'ignores non-existent scopes' do
      store.parse_scopes('basic,extended,megapowerful').sort.should == ['basic', 'extended']
    end
  end

end