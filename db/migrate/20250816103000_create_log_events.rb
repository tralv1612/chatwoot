class CreateLogEvents < ActiveRecord::Migration[7.0] # Version có thể khác
  def change
    create_table :log_events do |t|
      # Sử dụng t.references sẽ tự động thêm index và foreign key constraint
      t.references :account, null: false, foreign_key: true
      t.references :inbox,   null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :source_id
      t.string :event_name
      t.datetime :time
      t.string :link

      # t.timestamps sẽ tự động tạo 2 cột created_at và updated_at
      t.timestamps
    end
  end
end
