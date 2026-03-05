class DropActiveStorageTables < ActiveRecord::Migration[8.1]
  def change
        # Drop tables in reverse order due to foreign keys
    drop_table :active_storage_variant_records if table_exists?(:active_storage_variant_records)
    drop_table :active_storage_attachments if table_exists?(:active_storage_attachments)
    drop_table :active_storage_blobs if table_exists?(:active_storage_blobs)
  end
end
