# app/services/file_text_extractor.rb
class FileTextExtractor
  def self.extract(file)
    new(file).extract
  end

  def initialize(file)
    @file = file
    @ext = File.extname(file.original_filename).downcase
  end

  def extract
    case @ext
    when ".txt"
      @file.read
    when ".pdf"
      require "pdf-reader"
      PDF::Reader.new(@file.tempfile).pages.map(&:text).join("\n")
    when ".docx"
      require "docx"
      Docx::Document.open(@file.tempfile.path).paragraphs.map(&:text).join("\n")
    when ".html"
      require "nokogiri"
      Nokogiri::HTML(@file.read).text
    else
      raise "Unsupported file type: #{@ext}"
    end
  end
end
