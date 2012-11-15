class AddColumnsToNonce < ActiveRecord::Migration

  def self.up
    add_column :nonces, :endpoint, :text
    add_column :nonces, :context, :text
    add_column :nonces, :delivery_status_key, :text
  end

  def self.down
    remove_column :nonces, :endpoint
    remove_column :nonces, :context
    remove_column :nonces, :delivery_status_key
  end

end
