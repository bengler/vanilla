class AddActivatedColumnToUsers < ActiveRecord::Migration

  def self.up
    add_column :users, :activated, :boolean, :default => false, :null => false
    add_column :users, :activated_at, :timestamp
  end

  def self.down
    remove_column :users, :activated
    remove_column :users, :activated_at
  end

end
