class Document < ApplicationRecord
  has_many :chunks, dependent: :destroy
  before_create :generate_embedding
  after_create :chunk_content
  after_update :refresh_chunks

  # Gemini and OpenAI embedding configs
  GEMINI_MODEL     = "models/gemini-embedding-exp-03-07"
  GEMINI_ENDPOINT  = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-exp-03-07:embedContent"
  GEMINI_API_KEY   = ENV["GEMINI_API_KEY"]
  OPENAI_API_KEY   = ENV["OPENAI_ACCESS_TOKEN"]
  OPENAI_MODEL     = "text-embedding-3-small"

  # OpenAI client instance
  def self.openai_client
    @openai ||= OpenAI::Client.new(access_token: OPENAI_API_KEY)
  end

  # Retrieves vector search results for documents
  def self.search_similar(query, top_k: 3)
    embedding = embed_with_gemini(query) || embed_with_openai(query)
    return none unless embedding

    Document.order(Arel.sql("embedding <#> '[#{embedding.join(',')}]'")).limit(top_k)
  end

  # Split and create chunks from content
  def chunk_content
    TextSplitter.chunk(content).each_with_index do |chunk_text, index|
      chunks.create!(
        content: chunk_text,
        position: index + 1,
        token_count: chunk_text.split.size
      )
    end
  end

  private

  # Generates embedding before creation using Gemini (fallback to OpenAI)
  def generate_embedding
    embedding = self.class.embed_with_gemini(content) || self.class.embed_with_openai(content)
    self.embedding = "[#{embedding.join(',')}]" if embedding
  end

  # Re-chunk after document update
  def refresh_chunks
    chunks.destroy_all
    chunk_content
  end

  # Embed text using Gemini API
  def self.embed_with_gemini(text)
    return nil unless GEMINI_API_KEY.present?

    response = HTTParty.post(
      "#{GEMINI_ENDPOINT}?key=#{GEMINI_API_KEY}",
      headers: { "Content-Type" => "application/json" },
      body: {
        model: GEMINI_MODEL,
        content: { parts: [ { text: text } ] },
        taskType: "RETRIEVAL_DOCUMENT"
      }.to_json
    )

    if response.code == 200
      response.parsed_response.dig("embedding", "values")
    else
      Rails.logger.warn "Gemini fallback: #{response.code} - #{response.body}"
      nil
    end
  end

  # Embed text using OpenAI
  def self.embed_with_openai(text)
    return nil unless OPENAI_API_KEY.present?

    retries = 2
    begin
      response = openai_client.embeddings(
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
        Rails.logger.error "OpenAI rate limit exceeded."
        nil
      end
    rescue => e
      Rails.logger.error "OpenAI fallback failed: #{e.message}"
      nil
    end
  end
end
