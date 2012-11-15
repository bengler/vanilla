class AddIndexes < ActiveRecord::Migration

  def self.up
    add_index :users, :name
    add_index :users, :mobile_number
    add_index :users, :mobile_verified
    add_index :users, :email_address
    add_index :users, :email_verified
    add_index :users, :deleted
    add_index :users, :store_id
  end

  def self.down
    remove_index :users, :name
    remove_index :users, :mobile_number
    remove_index :users, :mobile_verified
    remove_index :users, :email_address
    remove_index :users, :email_verified
    remove_index :users, :deleted
    remove_index :users, :store_id
  end

end
