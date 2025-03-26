class CreateChunks < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE TABLE chunks (
        id SERIAL PRIMARY KEY,
        document_id INTEGER REFERENCES documents(id),
        content TEXT,
        embedding vector(3072),
        created_at TIMESTAMP,
        updated_at TIMESTAMP
      );
    SQL
  end

  def down
    execute "DROP TABLE chunks;"
  end
end
