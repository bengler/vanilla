# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    get '/:store/users/find' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      god_required!(@store)

      @users = nil
      %w(name mobile_number email_address).each do |attr|
        if (value = params[attr] and value.present?)
          @users ||= User
          @users = @users.where(attr => value)
        end
      end
      @users &&= @users.all
      @users ||= []
      
      [200, pg(:users, :locals => {:users => @users})]
    end

    get '/:store/users/:id' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = @store.users.where(:id => id).first
      halt 404 unless @user

      god_required!(@store) unless @user == current_user

      last_modified @user.updated_at
      etag @user.updated_at.to_i.to_s(36)

      stream do |out|
        out << pg(:user, :locals => {:user => @user})
      end
    end

    post '/:store/users' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      god_required!(@store)

      attrs = params.with_indifferent_access
      @user = User.new(:store => @store)
      @user.password_hash = ''
      @user.activated_at = Time.now
      @user.activated = true
      @user.logged_in = true
      @user.attributes = attrs.slice(
        :name, :mobile_number, :email_address,
        :birth_date, :gender)
      if god?
        @user.attributes = attrs.slice(
          :password_hash, :password, :mobile_verified, :email_verified,
          :activated, :activated_at)
      else
        # TODO: Move this into a security system
        %w(password_hash mobile_verified email_verified 
          activated activated_at).each do |attr|
          halt 403, "Not allowed to set attribute '#{attr}'" if attrs.include?(attr)
        end
        @user.attributes = attrs.slice(:password)
      end
      if god? and attrs[:activated_at]
        @user.save(:validate => false)  # Special cheat for Origo bootstrap script to work around invalid cruft
      else
        @user.save!
      end

      if attrs['created_at']
        User.update_all({:created_at => attrs['created_at']}, {:id => @user.id})
      end

      headers['Location'] = "/#{@store.name}/users/#{@user.id}"
      [201, pg(:user, :locals => {:user => @user})]
    end

    put '/:store/users/:id' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = @store.users.where(:id => id).first
      halt 404 unless @user
      
      god_required!(@store) unless @user == current_user
      
      attrs = params.with_indifferent_access
      @user.attributes = attrs.slice(
        :name, :mobile_number, :email_address,
        :birth_date, :gender)
      if god?
        @user.attributes = attrs.slice(
          :password_hash, :password, :mobile_verified, :email_verified,
          :activated, :activated_at)
      else
        # TODO: Move this into a security system
        %w(password_hash mobile_verified email_verified
          activated activated_at).each do |attr|
          halt 403, "Not allowed to set attribute '#{attr}'" if attrs.include?(attr)
        end
        @user.attributes = attrs.slice(:password)
      end
      @user.save!

      [200, pg(:user, :locals => {:user => @user})]
    end

    delete '/:store/users/:id' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = @store.users.where(:id => id).first
      halt 404 unless @user
      
      god_required!(@store) unless @user == current_user

      @user.delete!
      halt 200
    end

  end
end
