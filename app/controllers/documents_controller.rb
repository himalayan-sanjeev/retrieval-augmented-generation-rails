# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  def index
    @documents = Document.all
  end

  def new; end

  def create
    file = params[:file]

    if file && file.content_type == "text/plain"
      content = file.read
      Document.create!(content: content)
      redirect_to documents_path, notice: "Document uploaded and processed!"
    else
      redirect_to new_document_path, alert: "Only .txt files are supported."
    end
  end
end
