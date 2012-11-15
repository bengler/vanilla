class CreateStores < ActiveRecord::Migration

  def self.up
    create_table :stores do |t|
      t.timestamps
      t.text :name, :null => false
      t.text :default_url, :null => false
      t.text :template_url, :null => false
      t.text :scopes
      t.text :secret, :null => false
      t.text :user_name_pattern
      t.integer :minimum_user_name_length
      t.integer :maximum_user_name_length
      t.text :default_sender_email_address
      t.text :service_settings
    end
  end

  def self.down
    drop_table :stores
  end

end
