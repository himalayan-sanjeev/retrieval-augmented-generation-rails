# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]

  def index
    @documents = Document.all
  end

  def new; end

  def create
    uploaded_file = params[:file]
    return redirect_to documents_path, alert: "No file uploaded." unless uploaded_file

    content = FileTextExtractor.extract(uploaded_file)

    @document = Document.new(content: content)

    if @document.save
      redirect_to @document, notice: "Document uploaded!"
    else
      render :new
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
      debugger
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
