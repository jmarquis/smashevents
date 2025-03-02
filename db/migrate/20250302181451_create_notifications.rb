class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :notifiable, null: false, polymorphic: true
      t.boolean :success, null: false
      t.string :platform, null: false
      t.string :notification_type, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end
  end
end
