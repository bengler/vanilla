# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    ##
    # Render signup form.
    #
    # This will render the template `signup` with the following
    # parameters:
    #
    # * `return_url` - the return URL.
    #
    # @path store - the store name.
    # @param return_url - URL to return to use on cancelation, or if already logged
    # in.
    #
    get '/:store/signup' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store
      redirect_back if current_user

      custom_template!(:signup, :variables => {
        :submit_url => url_with_params("/#{@store.name}/signup", :return_url => return_url),
        :return_url => return_url
      })
    end

    ##
    # Sign up.
    #
    post '/:store/signup' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store
      redirect_back if current_user

      attrs = params
      @old_user = User.active.where(
        :mobile_number => attrs['mobile_number'],
        :mobile_verified => true).first
      if @old_user
        if @old_user.password_match?(attrs['password']) or
          @old_user.password_match?(attrs['password_confirmation'])
          # Mobile and password matches existing user
          logger.info("Existing user trying to register twice, use existing account ID=#{@old_user.id}")
          self.transitional_user = @old_user
          redirect_back
        else
          matches = []
          matches << 'mobile_number'
          matches << 'name' if User.name_match?(attrs['name'], @old_user.name)
          matches << 'email_address' if @old_user.email_address == attrs['email_address']
          matches.sort!
          custom_template!(:duplicate_signup, :status => 400, :variables => attrs.merge(
            :recovery_url => url_with_params("/#{@store.name}/recover",
              :identification => [attrs['mobile_number'], attrs['email_address']].select { |x| x.present? }.first,
              :return_url => return_url),
            :cancel_url => url_with_params("/#{@store.name}/signup",
              :return_url => return_url),
            :mobile_number => attrs['mobile_number'],
            :email_address => attrs['email_address'],
            :name => attrs['name'],
            :matches => matches.join(',')
          ))
        end
      end

      begin
        @user = User.new(
          :store => @store,
          :name => attrs['name'],
          :password => (attrs['password'] || ''),
          :password_confirmation => (attrs['password_confirmation'] || ''),
          :mobile_number => attrs['mobile_number'],
          :email_address => attrs['email_address'])
        @user.mobile_required = true
        @user.save!
      rescue ActiveRecord::RecordInvalid => e
        custom_template!(:signup, :status => 400, :variables => attrs.merge(
          :submit_url => url_with_params("/#{@store.name}/signup", :return_url => return_url),
          :error => exception_to_error_symbol(e),
          :return_url => return_url))
      else
        @nonce = send_nonce_to_mobile!(@user,
          :context => :signup,
          :return_url => url_with_params("/#{@store.name}/signup/complete",
            :return_url => return_url))
        redirect url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id)
      end
    end

    get '/:store/signup/complete' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = transitional_user || current_user
      halt 403, 'No user' unless @user
      halt 403, 'User not activated' unless @user.activated?

      if @user.email_address and not @user.email_verified?
        send_nonce_to_email!(@user, :context => :signup)
      end

      redirect return_url
    end

  end
end