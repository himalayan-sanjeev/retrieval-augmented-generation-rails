class Chunk < ApplicationRecord
  belongs_to :document
  validates :position, presence: true
  validates :token_count, presence: true

  before_create :generate_embedding
  before_save :update_tsvector

  attr_accessor :similarity_score

  # === Embedding configuration ===
  GEMINI_MODEL    = "models/gemini-embedding-exp-03-07"
  GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-exp-03-07:embedContent"
  OPENAI_MODEL    = "text-embedding-3-small"

  # === Embedding Generation ===

  # Generates embedding for the chunk content.
  # - Uses Gemini API by default.
  # - Falls back to OpenAI API if Gemini fails or key is missing.
  # - Stores result as a pgvector-compatible array string.
  def generate_embedding
    embedding = self.class.embed_with_gemini(content) || self.class.embed_with_openai(content)
    self.embedding = "[#{embedding.join(',')}]" if embedding
  end

  # === Embedding Helpers ===

  # Attempts to embed using Gemini API.
  # - Requires GEMINI_API_KEY to be present.
  # - Returns an array of floats if successful.
  def self.embed_with_gemini(text)
    return nil unless ENV["GEMINI_API_KEY"].present?

    response = HTTParty.post(
      "#{GEMINI_ENDPOINT}?key=#{ENV['GEMINI_API_KEY']}",
      headers: { "Content-Type" => "application/json" },
      body: {
        model: GEMINI_MODEL,
        content: { parts: [ { text: text } ] }
      }.to_json
    )

    if response.code == 200
      response.parsed_response.dig("embedding", "values")
    else
      Rails.logger.warn "Gemini fallback triggered: #{response.code} - #{response.body}"
      nil
    end
  end

  # Attempts to embed using OpenAI if Gemini fails.
  # - Requires OPENAI_ACCESS_TOKEN to be present.
  # - Retries on 429 (rate-limit) errors.
  def self.embed_with_openai(text)
    return nil unless ENV["OPENAI_ACCESS_TOKEN"].present?

    client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])
    retries = 2

    begin
      response = client.embeddings(
        parameters: {
          model: OPENAI_MODEL,
          input: text
        }
      )
      response["data"][0]["embedding"]
    rescue Faraday::TooManyRequestsError
      if (retries -= 1) >= 0
        sleep 1.5
        retry
      else
        Rails.logger.error "OpenAI rate limit exceeded"
        nil
      end
    rescue => e
      Rails.logger.error "OpenAI embedding error: #{e.message}"
      nil
    end
  end

  # Embeds a query for use in vector similarity search.
  # - Uses Gemini, falls back to OpenAI.
  # - Returns nil on error.
  def self.embed_query(query)
    embed_with_gemini(query) || embed_with_openai(query)
  end

  # === Search Methods ===

  # Pure vector search using pgvector's `<#>` distance operator.
  # - Retrieves top_k most similar chunks to the input query.
  def self.search_similar(query, top_k: 3)
    embedding = embed_query(query)
    return none unless embedding

    Chunk
      .select("chunks.*, (embedding <#> '[#{embedding.join(',')}]') AS similarity_score")
      .order("similarity_score ASC")
      .limit(top_k)
  end

  # Hybrid search using both:
  # - Vector similarity (semantic)
  # - Full-text (tsvector + plainto_tsquery)
  # Merges and ranks results.
  def self.hybrid_search(query, top_k: 3)
    embedding = embed_query(query)
    return none unless embedding

    # Semantic vector search
    semantic_matches = Chunk
      .select("chunks.*, (embedding <#> '[#{embedding.join(',')}]') AS distance")
      .order("distance ASC")
      .limit(top_k)

    # Keyword match via PostgreSQL full-text search
    keyword_matches = Chunk
      .where("tsv @@ plainto_tsquery('english', ?)", query)
      .limit(top_k)

    # Merge and sort by distance (semantic first, fallback 0.5)
    combined = (semantic_matches + keyword_matches).uniq(&:id)
    combined.sort_by { |c| c.try(:distance) || 0.5 }.first(top_k)
  end

  # === Full-Text Search Vector Update ===

  # Populates the `tsv` column using PostgreSQL `to_tsvector`.
  # - Used for full-text matching in hybrid search.
  def update_tsvector
    self.tsv = ActiveRecord::Base.sanitize_sql_array([ "to_tsvector('english', ?)", content ])
  end
end
