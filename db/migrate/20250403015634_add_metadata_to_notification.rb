class AddMetadataToNotification < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :metadata, :json
  end
end
