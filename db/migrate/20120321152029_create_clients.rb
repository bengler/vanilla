class CreateClients < ActiveRecord::Migration

  def self.up
    create_table :clients do |t|
      t.timestamps
      t.integer :store_id, :null => false
      t.text :title, :null => false
      t.text :secret, :null => false
      t.text :api_key, :null => false
      t.text :oauth_redirect_uri
    end
    execute "alter table clients add foreign key (store_id) references stores"
  end

  def self.down
    drop_table :clients
  end

end
