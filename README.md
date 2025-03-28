# 📚 RAG Demo App (Ruby on Rails + Gemini)

A simple, clean Retrieval-Augmented Generation (RAG) app built in **Ruby on Rails**, using **Gemini** for embeddings and generative AI.

---

## 🚀 Features

- Upload `.txt` / `.pdf` / `.docx` / `.html`/ `.rb`/ `.py`/ `.md` documents as knowledge base
- Automatic document chunking & vector embeddings (Gemini API)
- Semantic search powered by pgvector
- LLM-generated answers grounded in uploaded documents
- Dashboard for content/documents management
- Clean UI with TailwindCSS + Slim

---

## 🧠 How It Works

1. **Upload Documents**  
   Uploads are chunked and stored with vector embeddings.

2. **Query the System**  
   Users ask natural-language questions.

3. **Search & Retrieval**  
   The app uses semantic search to find relevant chunks.

4. **Generate Answers**  
   Retrieved chunks are sent to Gemini to generate grounded, accurate responses.

---

## ⚙️ Tech Stack

- Ruby on Rails 8
- pgvector + PostgreSQL
- Gemini API (Google AI)
- TailwindCSS + Slim

---

## 📥 Setup Instructions

```bash
git clone https://github.com/himalayan-sanjeev/retrieval-augmented-generation-rails
cd retrieval-augmented-generation-rails

bundle install
yarn install

# Add your GEMINI_API_KEY to .env

rails db:create db:migrate
rails server
