# encoding: utf-8

module Vanilla

  class V1 < Sinatra::Base

    get '/stores' do
      god_required!  # TODO: Check for root god?

      @stores = Store.all
      pg(:stores, :locals => {:stores => @stores})
    end

    get '/stores/:name' do |name|
      @store = Store.where(:name => name).first
      halt 404 unless @store

      god_required!(@store)

      last_modified @store.updated_at
      etag @store.updated_at.to_i.to_s(36)

      stream do |out|
        out << pg(:store, :locals => {:store => @store})
      end
    end

    put '/stores' do
      god_required!  # TODO: Check for root god?

      @store = Store.new
      @store.attributes = params.with_indifferent_access.except(:session, :captures, :splat)
      @store.save!

      headers['Location'] = "/stores/#{@store.name}"
      [201, pg(:store, :locals => {:store => @store})]
    end

    post '/stores/:name' do |name|
      @store = Store.where(:name => name).first
      halt 404 unless @store

      god_required!(@store)

      @store.attributes = params.with_indifferent_access.except(:session, :captures, :splat)
      @store.save!

      [200, pg(:store, :locals => {:store => @store})]
    end

  end
end
