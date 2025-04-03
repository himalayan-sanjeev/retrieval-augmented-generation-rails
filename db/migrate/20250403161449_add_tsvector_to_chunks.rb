class AddTsvectorToChunks < ActiveRecord::Migration[8.0]
  def change
    add_column :chunks, :tsv, :tsvector
    add_index  :chunks, :tsv, using: :gin
  end
end
