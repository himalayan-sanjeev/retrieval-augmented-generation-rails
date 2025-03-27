class TextSplitter
  def self.chunk(text, chunk_size: 50)
    text.scan(/\b(?:\w+\b\W*){1,#{chunk_size}}/)
  end
end
