class TextSplitter
  require "nokogiri"

  def self.chunk(text, chunk_size: 50)
    debugger
    # Split the text into sentences using a simple sentence delimiter
    sentences = text.scan(/[^.!?]+[.!?]/).map(&:strip)

    # Group sentences into chunks based on a target word count per chunk
    chunks = []
    current_chunk = ""
    current_count = 0

    sentences.each do |sentence|
      word_count = sentence.split.size
      if current_count + word_count > chunk_size
        chunks << current_chunk.strip unless current_chunk.empty?
        current_chunk = sentence
        current_count = word_count
      else
        current_chunk += " #{sentence}"
        current_count += word_count
      end
    end

    chunks << current_chunk.strip unless current_chunk.empty?
    chunks
  end
end
