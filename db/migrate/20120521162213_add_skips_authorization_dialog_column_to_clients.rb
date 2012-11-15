class AddSkipsAuthorizationDialogColumnToClients < ActiveRecord::Migration

  def self.up
    add_column :clients, :skips_authorization_dialog, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :clients, :skips_authorization_dialog
  end

end
