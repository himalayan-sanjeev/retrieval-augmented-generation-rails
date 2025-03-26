class Document < ApplicationRecord
  has_many :chunks, dependent: :destroy
  before_create :generate_embedding
  after_create :chunk_content
  after_update :refresh_chunks

  EMBEDDING_MODEL = "text-embedding-ada-002"
  GEMINI_MODEL = "models/gemini-embedding-exp-03-07"
  GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-exp-03-07:embedContent"
  GEMINI_API_KEY = ENV.fetch("GEMINI_API_KEY", nil)

  def self.openai_client
    @openai = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY", nil))
  end

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
    vector = "[#{embedding.join(',')}]"

    Document
      .order(Arel.sql("embedding <#> '#{vector}'")) # <#> = cosine distance
      .limit(top_k)
  end

  def chunk_content
    TextSplitter.chunk(content).each do |chunk_text|
      chunks.create!(content: chunk_text)
    end
  end

  private

  def generate_embedding
    response = HTTParty.post(
      "#{GEMINI_ENDPOINT}?key=#{GEMINI_API_KEY}",
      headers: { "Content-Type" => "application/json" },
      body: {
        model: GEMINI_MODEL,
        content: {
          parts: [
            { text: content }
          ]
        },
      taskType: "RETRIEVAL_DOCUMENT"
    }.to_json
    )

    if response.code == 200
      values = response.parsed_response.dig("embedding", "values")
      self.embedding = "[#{values.join(',')}]"
    else
      Rails.logger.error "Gemini Error: #{response.parsed_response}"
      self.embedding = nil
    end
  end

  def refresh_chunks
    chunks.destroy_all
    chunk_content
  end

  def generate_embedding_using_openai
    response = self.class.openai_client.embeddings(
      parameters: {
        model: EMBEDDING_MODEL,
        input: content
      }
    )

    self.embedding = response["data"][0]["embedding"]
  end
end
