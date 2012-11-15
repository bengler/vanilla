# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    helpers do
      # TODO: Refactor into a single verification code controller
      def short_change_validation_url(nonce)
        base64 = encode_params_base64(
          :nonce_id => nonce.id,
          :code => nonce.value)
        url("/#{nonce.store.name}/users/v/#{base64}")
      end

      def edit_user_template_variables
        @user.attributes.with_indifferent_access.slice(
          :password, :password_confirmation,
          :mobile_number, :mobile_verified,
          :email_address, :email_verified
        ).merge(
          :has_current_password => @user.password_hash.present?,
          :submit_url => url_with_params("/#{@store.name}/users/#{@user.id}/edit",
            :return_url => return_url),
          :edit_mobile_url => url_with_params("/#{@store.name}/users/#{@user.id}/mobile",
            :return_url => return_url),
          :edit_email_url => url_with_params("/#{@store.name}/users/#{@user.id}/email",
            :return_url => return_url))
      end

      def change_mobile_template_variables
        @user.attributes.with_indifferent_access.slice(
          :mobile_number
        ).merge(
          :submit_url => url_with_params("/#{@store.name}/users/#{@user.id}/mobile",
            :return_url => return_url),
          :return_url => return_url)
      end

      def change_email_template_variables
        @user.attributes.with_indifferent_access.slice(
          :email_address
        ).merge(
          :submit_url => url_with_params("/#{@store.name}/users/#{@user.id}/email",
            :return_url => return_url),
          :return_url => return_url)
      end
    end

    get '/:store/users/:id/edit' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = User.active.where(:id => id).first
      halt 404 unless @user

      god_required!(@store) if @user != current_user

      custom_template!(:edit_user, :variables => edit_user_template_variables)
    end

    post '/:store/users/:id/edit' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = User.active.where(:id => id).first
      halt 404 unless @user

      god_required!(@store) if @user != current_user

      begin
        if @user.password_hash.present?
          # Force validation of current password if we're not a god
          @user.current_password = '' unless god?
          @user.attributes = params.with_indifferent_access.slice(
            :password, :password_confirmation, :current_password)
        else
          @user.attributes = params.with_indifferent_access.slice(
            :password, :password_confirmation)
        end

        @user.save!
      rescue ActiveRecord::RecordInvalid => e
        custom_template!(:edit_user, :status => 400,
          :variables => edit_user_template_variables.merge(
            :error => exception_to_error_symbol(e),
            :return_url => return_url))
      else
        redirect return_url
      end
    end

    get '/:store/users/:id/mobile' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = User.active.where(:id => id).first
      halt 404 unless @user

      god_required!(@store) if @user != current_user

      custom_template!(:change_mobile,
        :variables => change_mobile_template_variables)
    end

    post '/:store/users/:id/mobile' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = User.active.where(:id => id).first
      halt 404 unless @user

      god_required!(@store) if @user != current_user

      begin
        @user.mobile_required = true
        @user.attributes = params.with_indifferent_access.slice(:mobile_number)
        @user.mobile_verified = true if god?
        @user.save!
      rescue ActiveRecord::RecordInvalid => e
        custom_template!(:change_mobile, :status => 400,
          :variables => change_mobile_template_variables.merge(
            :error => exception_to_error_symbol(e),
            :return_url => return_url))
      else
        if god?
          redirect return_url
        else
          @nonce = send_nonce_to_mobile!(@user,
            :context => :change,
            :return_url => return_url)
          redirect url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id)
        end
      end
    end

    get '/:store/users/:id/email' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = User.active.where(:id => id).first
      halt 404 unless @user

      god_required!(@store) if @user != current_user

      custom_template!(:change_email,
        :variables => change_email_template_variables)
    end

    post '/:store/users/:id/email' do |store, id|
      @store = Store.where(:name => store).first
      halt 404 unless @store

      @user = User.active.where(:id => id).first
      halt 404 unless @user

      god_required!(@store) if @user != current_user

      begin
        @user.email_required = true
        @user.attributes = params.with_indifferent_access.slice(:email_address)
        @user.email_verified = true if god?
        @user.save!
      rescue ActiveRecord::RecordInvalid => e
        custom_template!(:change_email, :status => 400,
          :variables => change_email_template_variables.merge(
            :error => exception_to_error_symbol(e),
            :return_url => return_url))
      else
        if god?
          redirect return_url
        else
          @nonce = send_nonce_to_email!(@user,
            :context => :change)
          custom_template!(:verification_code_sent, :variables => {
            :context => :change,
            :endpoint => :email,
            :submit_url => url_with_params("/#{@store.name}/verify", :nonce_id => @nonce.id),
            :return_url => return_url
          })
        end
      end
    end

  end
end
