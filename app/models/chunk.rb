class Chunk < ApplicationRecord
  belongs_to :document
  validates :position, presence: true
  validates :token_count, presence: true

  before_create :generate_embedding
  before_save :update_tsvector
  attr_accessor :similarity_score

  GEMINI_MODEL = "models/gemini-embedding-exp-03-07"
  GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-exp-03-07:embedContent"

  # Generate vector embedding for chunk content using Gemini API.
  # - Sends content to Gemini API for embedding generation.
  # - Parses the response to extract the embedding values.
  # - Updates the `embedding` attribute with the generated vector.
  # - Logs an error if the API call fails or returns an unexpected response.
  def generate_embedding
    response = HTTParty.post(
      "#{GEMINI_ENDPOINT}?key=#{ENV['GEMINI_API_KEY']}",
      headers: { "Content-Type" => "application/json" },
      body: {
        model: GEMINI_MODEL,
        content: { parts: [ { text: content } ] }
      }.to_json
    )

    if response.code == 200
      values = response.parsed_response.dig("embedding", "values")
      self.embedding = "[#{values.join(',')}]" if values
    else
      Rails.logger.error "Gemini embedding error: #{response.parsed_response}"
    end
  end

  # Perform pure vector-based semantic search using the Gemini API.
  # - Sends the query to the Gemini API for embedding generation.
  # - Receives the embedding and uses it to find similar chunks.
  # - Returns the top_k most similar chunks based on vector distance.
  # - Uses the `<#>` operator for vector distance calculation.
  # - Returns `none` if no embedding is found or if the API call fails.
  def self.search_similar(query, top_k: 3)
    response = HTTParty.post(
      "#{GEMINI_ENDPOINT}?key=#{ENV['GEMINI_API_KEY']}",
      headers: { "Content-Type" => "application/json" },
      body: {
        model: GEMINI_MODEL,
        content: {
          parts: [ { text: query } ]
        }
      }.to_json
    )

    embedding = response.dig("embedding", "values")

    return none unless embedding.present?

    Chunk
    .select("chunks.*, (embedding <#> '[#{embedding.join(',')}]') AS similarity_score")
    .order("similarity_score ASC")
    .limit(top_k)
  end

  # Performs a hybrid search combining semantic (vector-based) similarity and keyword (text-based) matching.
  # - Uses vector distance (<#>) for semantic similarity via Gemini embeddings.
  # - Uses PostgreSQL full-text search (tsvector) for exact keyword match.
  # - Merges and ranks results to prioritize most relevant chunks.
  # - Returns top_k most relevant chunks.
  def self.hybrid_search(query, top_k: 3)
    embedding = embed_query(query)
    return none unless embedding.present?

    # Performs semantic vector search using the `<#>` operator provided by pgvector.
    # - Calculates the distance between each chunk's embedding and the query embedding.
    # - Selects each chunk along with a computed `distance` score.
    # - Orders results by ascending distance (i.e., most semantically similar first).
    # - Limits the number of results to `top_k`.
    semantic_matches = Chunk
      .select("chunks.*, (embedding <#> '[#{embedding.join(',')}]') AS distance")
      .order("distance ASC")
      .limit(top_k)

    # Performs keyword-based full-text search using PostgreSQL's `tsvector` and `plainto_tsquery`.
    # - Matches chunks whose `tsv` column (text search vector/ tokenized document text) matches the query.
    # - Uses `plainto_tsquery` to convert the input query into an tsquery object (a text search query format (i.e. plain format).
    # - `@@` is the PostgreSQL full-text search match operator.
    # - This automatically handles tokenization, stop words, etc., making it suitable for natural language input.
    # - Returns chunks that have keyword-level relevance to the input query.
    # - Limits the number of results to `top_k`.
    keyword_matches = Chunk.where("tsv @@ plainto_tsquery('english', ?)", query).limit(top_k)

    combined = (semantic_matches + keyword_matches).uniq(&:id)

    # Sort by semantic distance (lower is better), fallback to 0.5 for keyword-only matches
    combined.sort_by { |c| c.try(:distance) || 0.5 }.first(top_k)
  end

  private

  # Update tsvector column for PostgreSQL full-text search
  # - Uses `to_tsvector` to convert the content into a tsvector format.
  # - The `english` configuration is used for English language processing.
  # - This is called before saving the record to ensure the tsvector is always up-to-date.
  # - It uses `ActiveRecord::Base.sanitize_sql_array` to safely construct the SQL query.
  def update_tsvector
    self.tsv = ActiveRecord::Base.sanitize_sql_array([ "to_tsvector('english', ?)", content ])
  end

  # Get embedding vector from Gemini API for a query
  # - Sends the query to the Gemini API for embedding generation.
  # - Receives the embedding and returns it as an array of values.
  # - Returns `nil` if no embedding is found or if the API call fails.
  def self.embed_query(query)
    response = HTTParty.post(
      "#{GEMINI_ENDPOINT}?key=#{ENV['GEMINI_API_KEY']}",
      headers: { "Content-Type" => "application/json" },
      body: {
        model: GEMINI_MODEL,
        content: { parts: [ { text: query } ] }
      }.to_json
    )

    response.dig("embedding", "values")
  end
end
