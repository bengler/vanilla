class CreateNonces < ActiveRecord::Migration

  def self.up
    create_table :nonces do |t|
      t.timestamps
      t.integer :store_id, :null => false
      t.text :key, :null => false
      t.text :value, :null => false
      t.text :url
      t.timestamp :expires_at, :null => false
      t.integer :user_id, :null => false
    end
    add_index :nonces, [:store_id, :key, :value]
    execute "alter table nonces add foreign key (store_id) references stores"
    execute "alter table nonces add foreign key (user_id) references users"
  end

  def self.down
    drop_table :nonces
  end

end
