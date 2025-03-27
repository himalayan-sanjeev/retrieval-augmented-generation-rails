class Chunk < ApplicationRecord
  belongs_to :document
  validates :position, presence: true
  validates :token_count, presence: true

  before_create :generate_embedding
  attr_accessor :similarity_score

  GEMINI_MODEL = "models/gemini-embedding-exp-03-07"
  GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-exp-03-07:embedContent"

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

  def self.search_similar(query, top_k: 5)
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

    return Chunk.none unless embedding.present?

    Chunk
    .select("chunks.*, (embedding <#> '[#{embedding.join(',')}]') AS similarity_score")
    .order("similarity_score ASC")
    .limit(top_k)
  end
end
