class CreateUsers < ActiveRecord::Migration

  def self.up
    create_table :users do |t|
      t.timestamps
      t.integer :store_id, :null => false
      t.text :name, :null => false
      t.text :password_hash, :null => false
      t.text :mobile_number
      t.boolean :mobile_verified, :null => false, :default => false
      t.text :email_address
      t.boolean :email_verified, :null => false, :default => false
      t.date :birth_date
      t.text :gender
    end
    execute "alter table users add foreign key (store_id) references stores"
  end

  def self.down
    drop_table :users
  end

end
