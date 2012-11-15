class CreateAuthorizations < ActiveRecord::Migration

  def self.up
    create_table :authorizations do |t|
      t.timestamps
      t.integer :user_id, :null => false
      t.integer :client_id, :null => false
      t.timestamp :code_expires_at, :null => false
      t.text :redirect_url, :null => false
      t.text :code, :null => false
      t.text :scopes
    end
    execute "alter table authorizations add foreign key (client_id) references clients"
    execute "alter table authorizations add foreign key (user_id) references users"
  end

  def self.down
    drop_table :authorizations
  end

end
