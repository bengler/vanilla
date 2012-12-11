class RemoveServiceSettingsAndAddHermestSessionToStores < ActiveRecord::Migration
  def self.up
    add_column :stores, :hermes_session, :text
    remove_column :stores, :service_settings
  end

  def self.down
    add_column :stores, :service_settings, :text
    remove_column :stores, :hermes_session
  end
end
