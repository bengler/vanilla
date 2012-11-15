# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    ##
    # Render form requesting that a recovery code should be sent to one of the
    # user's registered endpoints (mobile or email).
    #
    # This will render the template `recovery_request` with the following
    # parameters:
    #
    # * `return_url` - the return URL.
    #
    # @path store - the store name.
    # @param return_url - URL to return to use on cancelation, or if already logged
    # in.
    #
    get '/:store/recover' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      return_url = params[:return_url]
      return_url ||= @store.default_url

      redirect return_url if current_user

      custom_template!(:recovery_request, :variables => {
        :submit_url => url("/#{@store.name}/recover?return_url=#{CGI.escape(return_url)}"),
        :mobile_number => params[:mobile_number],
        :return_url => return_url
      })
    end

    ##
    # Request recovery.
    #
    post '/:store/recover' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      return_url = params[:return_url]
      return_url ||= @store.default_url

      redirect return_url if current_user

      begin
        @user, @endpoint = @store.identify(params[:identification], [:email, :mobile])
      rescue Store::IdentificationError => e
        custom_template!(:recovery_request, :status => 403, :variables => {
          :submit_url => url("/#{@store.name}/request?return_url=#{CGI.escape(return_url)}"),
          :identification => params[:identification],
          :error => exception_to_error_symbol(e),
          :return_url => return_url
        })
      else
        case @endpoint
          when :mobile
            @nonce = send_nonce_to_mobile!(@user,
              :context => :recovery,
              :return_url => url_with_params("/#{@store.name}/recover/password",
                :return_url => return_url))
            redirect url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id)
          when :email
            send_nonce_to_email!(@user,
              :context => :recovery,
              :return_url => url_with_params("/#{@store.name}/recover/password",
                :return_url => return_url))
            custom_template!(:verification_code_sent, :variables => {
              :context => :recovery,
              :endpoint => @endpoint,
              :return_url => return_url
            })
        end
      end
    end

    ##
    # Renders password change form.
    #
    get '/:store/recover/password' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store
      halt 403 unless current_user

      custom_template!(:recovery_password_change, :variables => {
        :submit_url => url_with_params("/#{@store.name}/recover/password", :return_url => return_url),
        :return_url => return_url
      })
    end

    ##
    # Submits password form.
    #
    post '/:store/recover/password' do |store|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = current_user
      halt 403 unless @user

      begin
        @user.attributes = params.with_indifferent_access.slice(:password, :password_confirmation)
        @user.password ||= ''
        @user.password_confirmation ||= ''
        @user.save!
      rescue ActiveRecord::RecordInvalid => e
        custom_template!(:recovery_password_change, :status => 400, :variables => {
          :submit_url => url_with_params("/#{@store.name}/recover/password", :return_url => return_url),
          :return_url => return_url,
          :error => exception_to_error_symbol(e)
        })
      end
      redirect return_url
    end

  end
end