class CreateDocumentsWithVector < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE TABLE documents (
        id SERIAL PRIMARY KEY,
        content TEXT,
        embedding vector(3072),
        created_at TIMESTAMP,
        updated_at TIMESTAMP
      );
    SQL
  end

  def down
    execute "DROP TABLE documents;"
  end
end
