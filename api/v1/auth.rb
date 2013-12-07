# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    ## Authenticate a user by identification and password.
    #
    post '/:store/auth' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store
      @user = @store.authenticate(params[:identification], params[:password])
      pg :user, :locals => {:user => @user}
    end

    ## Authenticate a user by identification and password.
    #
    post '/:store/auth/:uid' do |store, uid|
      @store = Store.where(:name => store).first
      halt 404 unless @store
      @user = @store.users.active.where(:id => uid.to_i).first if uid.to_i != 0
      halt 404 unless @user
      halt 403 unless @user.password_match?(params[:password])
      pg :user, :locals => {:user => @user}
    end

    get '/:store/login' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store
      redirect_back if transitional_user
      custom_template!(:login, :variables => {
        :submit_url => url_with_return_url("/#{@store.name}/login"),
        :return_url => return_url,
        :target_url => params[:target_url]
      })
    end

    # Authenticate a user. If the user with the provided ID is already logged in,
    # go straight to the return URL; otherwise, log out the current user and show
    # the login form.
    #
    get '/:store/login/:id' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      if transitional_user and transitional_user.id.to_s == id.to_s
        redirect_back
      else
        self.transitional_user = nil
        custom_template!(:login, :variables => {
          :submit_url => url_with_return_url("/#{@store.name}/login"),
          :return_url => return_url,
          :target_url => params[:target_url]
        })
      end
    end

    post '/:store/login' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      self.transitional_user = nil

      begin
        @user = @store.authenticate(params[:identification], params[:password])
      rescue Store::AuthenticationError => e
        custom_template!(:login, :status => 403, :variables => {
          :submit_url => url_with_return_url("/#{@store.name}/login"),
          :identification => params[:identification],
          :error => exception_to_error_symbol(e),
          :target_url => params[:target_url],
          :return_url => return_url
        })
      else
        logger.info "Setting user ID=#{@user.id} as logged in"
        @user.logged_in = true
        @user.save(:validate => false)

        self.transitional_user = @user

        redirect_back
      end
    end

    post '/:store/logout' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = current_user
      @user ||= transitional_user
      if @user
        logger.info "Setting user ID=#{@user.id} as logged out"
        @user.logged_in = false
        @user.save(:validate => false)

        self.transitional_user = nil
      end

      redirect_back
    end

    post '/:store/logout/:id' do |store, id|
      @store = Store.where(:name => store).first
      halt 404, "Store not found" unless @store

      @user = @store.users.where(:id => id).first
      halt 404, "User not found" unless @user

      god_required!(@store) unless @user == transitional_user

      logger.info "Setting user ID=#{@user.id} as logged out"
      @user.logged_in = false
      @user.save(:validate => false)

      self.transitional_user = nil if transitional_user == @user

      200
    end

  end
end