class SearchController < ApplicationController
  GEMINI_GENERATION_MODEL = "models/gemini-1.5-flash-latest"
  GEMINI_API_KEY = ENV.fetch("GEMINI_API_KEY", nil)
  GENERATION_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/#{GEMINI_GENERATION_MODEL}:generateContent"

  def index; end

  def query
    query_text = params[:query]
    hybrid_enabled = params[:hybrid].present?

    @results = if hybrid_enabled
                Chunk.hybrid_search(query_text, top_k: 3)
    else
                Chunk.search_similar(query_text, top_k: 3)
    end

    context = @results.map(&:content).join("\n---\n")
    @response = generate_response(query_text, context)

    render :index
  end

  private

  # Generates a response using the Gemini API based on the provided query and context.
  # - Sends a request to the Gemini API with the query and context.
  # - Parses the response to extract the generated text.
  # - Returns the generated text.
  def generate_response(query, context)
    response = HTTParty.post(
      "#{GENERATION_ENDPOINT}?key=#{GEMINI_API_KEY}",
      headers: { "Content-Type" => "application/json" },
      body: {
        contents: [
          {
            parts: [
              {
                text: "Answer the question based on the following context:\n\n#{context}\n\nQuestion: #{query}"
              }
            ]
          }
        ]
      }.to_json
    )
    response.dig("candidates", 0, "content", "parts", 0, "text")
  end
end
