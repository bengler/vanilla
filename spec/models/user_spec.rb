require 'spec_helper'

include Vanilla

describe User do

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

  describe '#password_match?' do
    it 'returns false if user has no password' do
      user = User.new(:name => 'Dingbat Nordmann', :store => store)
      user.password_match?('Yes we have no bananas').should == false
    end

    it 'returns true if password matches' do
      user = User.new(:name => 'Dingbat Nordmann', :store => store)
      user.password = 'sekrit'
      user.save!
      user.password_match?('sekrit').should == true
    end

    it 'returns false if password is different' do
      user = User.new(:name => 'Dingbat Nordmann', :store => store)
      user.password = 'sekrit'
      user.save!
      user.password_match?('Sekrit').should == false
    end
  end

  it 'validates name from pattern in store settings' do
    store = store!(
      :user_name_pattern => /\A[ai]+\z/,
      :minimum_user_name_length => 1,
      :maximum_user_name_length => 100)

    %w(bob John arne Aaaai).each do |bad_name|
      user = User.new(:name => bad_name, :store => store)
      user.valid?
      user.errors.get(:name).should_not == nil
    end
    %w(a aaaa aaaaaaa ai aiaiaiaiai aiiiiii).each do |good_name|
      user = User.new(:name => good_name, :store => store)
      user.valid?
      user.errors.get(:name).should == nil
    end
  end

  it 'validates name from minimum length in store settings' do
    store = store!(
      :minimum_user_name_length => 3,
      :maximum_user_name_length => 100)

    (1..2).to_a.each do |length|
      user = User.new(:name => ("x" * length), :store => store)
      user.valid?
      user.errors.get(:name).should_not == nil
    end
    (3..100).to_a.each do |length|
      user = User.new(:name => ("x" * length), :store => store)
      user.valid?
      user.errors.get(:name).should == nil
    end
  end

  it 'validates name from maximum length in store settings' do
    store = store!(
      :minimum_user_name_length => 1,
      :maximum_user_name_length => 5)

    (6..50).to_a.each do |length|
      user = User.new(:name => ("x" * length), :store => store)
      user.valid?
      user.errors.get(:name).should_not == nil
    end
    (1..5).to_a.each do |length|
      user = User.new(:name => ("x" * length), :store => store)
      user.valid?
      user.errors.get(:name).should == nil
    end
  end

  def store!(attributes)
    Store.create!({
      :name => 'mystore',
      :template_url => 'http://example.com/template',
      :default_url => 'http://example.com/',
      :default_sender_email_address => 'Example <notifications@example.com>',
      :hermes_session => 'god',
      :scopes => {
        'basic' => 'Just basic stuff',
        'extended' => 'Bags of stuff'
      }
    }.merge(attributes))
  end

end