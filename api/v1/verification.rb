# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    helpers do
      def short_verification_url(nonce)
        base64 = encode_params_base64(
          :nonce_id => nonce.id,
          :code => nonce.value)
        url("/#{nonce.store.name}/v/#{base64}")
      end
    end

    get '/:store/verify' do |store|
      do_verify_code(store)
    end

    post '/:store/verify' do |store|
      do_verify_code(store)
    end

    get '/:store/v/:base64' do |store, base64|
      params.merge!(decode_params_base64(base64))
      do_verify_code(store)
    end

    def do_verify_code(store)
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @nonce = Nonce.where(:id => params[:nonce_id]).first
      unless @nonce
        custom_template!(:error, :status => 403, :variables => {
          :error => :invalid_code
        })
      end

      self.return_url = @nonce.url

      @user, @endpoint, @context = @nonce.user, @nonce.endpoint, @nonce.context

      @delivery_status_url = @nonce.delivery_status_key ?
        url("/#{@store.name}/delivery_status/#{@nonce.delivery_status_key}") : nil

      if @nonce.expired?
        custom_template!(:verification_code_validation, :status => 403, :variables => {
          :context => @context,
          :endpoint => @endpoint,
          :submit_url => url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id),
          :delivery_status_url => @delivery_status_url,
          :return_url => return_url,
          :error => :expired_code
        })
      end

      unless params[:code]
        custom_template!(:verification_code_validation, :variables => {
          :context => @context,
          :endpoint => @endpoint,
          :submit_url => url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id),
          :delivery_status_url => @delivery_status_url,
          :return_url => return_url
        })
      end

      unless params[:code] == @nonce.value
        custom_template!(:verification_code_validation, :status => 403, :variables => {
          :context => @context,
          :endpoint => @endpoint,
          :submit_url => url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id),
          :delivery_status_url => @delivery_status_url,
          :error => :invalid_code,
          :return_url => return_url
        })
      end

      begin
        case @endpoint
          when :mobile
            @user.mobile_verified = true
          when :email
            @user.email_verified = true
        end
        @user.save!
      rescue ActiveRecord::RecordInvalid => e
        custom_template!(:verification_code_validation, :status => 400, :variables => attrs.merge(
          :context => @context,
          :endpoint => @endpoint,
          :submit_url => url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id),
          :delivery_status_url => @delivery_status_url,
          :error => exception_to_error_symbol(e),
          :return_url => return_url))
      else
        case @nonce.context
          when :signup, :recovery
            @user.activate!
            self.transitional_user = @user
        end
        @nonce.expired!
        redirect_back
      end
    end

    get '/:store/delivery_status/:id' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store
      halt 404 unless id =~ /\A\d+\Z/

      begin
        message = Pebblebed::Connector.new.hermes.get("/#{@store.name}/message/#{id}")
      rescue Pebblebed::HttpError => e
        halt 500 unless e.status == 404
        halt e.status
      else
        if message.include?('status')
          pg :delivery_status, {'status' => message['status']}
        else
          pg :delivery_status, {'status' => 'unknown'}
        end
      end
    end

  end
end