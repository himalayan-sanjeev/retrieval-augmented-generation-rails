class SearchController < ApplicationController
  def index; end

  def query
    query_text = params[:query]
    @results = Chunk.search_similar(query_text, top_k: 5)
    render :index
  end
end
