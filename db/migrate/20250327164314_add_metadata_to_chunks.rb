class AddMetadataToChunks < ActiveRecord::Migration[8.0]
  def change
    add_column :chunks, :position, :integer
    add_column :chunks, :token_count, :integer
  end
end
