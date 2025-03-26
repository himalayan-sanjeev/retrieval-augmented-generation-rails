class Document < ApplicationRecord
  before_create :generate_embedding

  EMBEDDING_MODEL = "text-embedding-ada-002"
  GEMINI_MODEL = "models/gemini-embedding-exp-03-07"
  GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-exp-03-07:embedContent"
  GEMINI_API_KEY = ENV.fetch("GEMINI_API_KEY", nil)

  def self.openai_client
    @openai = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY", nil))
  end


  private

  def generate_embedding
    debugger
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
