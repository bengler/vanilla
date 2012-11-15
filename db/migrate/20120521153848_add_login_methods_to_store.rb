class AddLoginMethodsToStore < ActiveRecord::Migration

  def self.up
    add_column :stores, :login_methods, :text
  end

  def self.down
    remove_column :stores, :login_methods
  end

end
