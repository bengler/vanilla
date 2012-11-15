class CreateTokens < ActiveRecord::Migration

  def self.up
    create_table :tokens do |t|
      t.timestamps
      t.integer :user_id, :null => false
      t.integer :client_id, :null => false
      t.text :authorization_code, :null => false
      t.text :access_token, :null => false
      t.text :refresh_token, :null => false
      t.text :scopes
      t.timestamp :expires_at
    end
    execute "alter table tokens add foreign key (client_id) references clients"
    execute "alter table tokens add foreign key (user_id) references users"
  end

  def self.down
    drop_table :tokens
  end

end
