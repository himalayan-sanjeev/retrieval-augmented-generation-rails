# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]

  def index
    @documents = Document.all
    @chunks = Chunk.all
  end

  def new; end

  def create
    content = params[:file]&.read || params[:document][:content]

    if content.blank?
      redirect_to new_document_path, alert: "Please upload a file or paste some content."
      return
    end

    @document = Document.new(content: content)

    if @document.save
      redirect_to @document, notice: "Document uploaded successfully!"
    else
      render :new, alert: "Failed to upload document."
    end
  end

  def show
  end

  def edit
  end

  def update
    if @document.update(document_params)
      redirect_to @document, notice: "Document updated."
    else
      render :edit
    end
  end

  def destroy
    @document.destroy
    redirect_to documents_path, notice: "Document deleted."
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:content)
  end
end
