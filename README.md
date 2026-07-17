# C++ Assistant — A RAG System Built on StackOverflow Data

A retrieval-augmented generation (RAG) system that answers C++ programming questions grounded strictly in a curated dataset of real StackOverflow Q&A, rather than relying on the LLM's raw parametric knowledge.

> Presented by Rashed Jafry

---

## Overview

C++ Assistant retrieves relevant, high-quality StackOverflow Q&A pairs for a user's question and uses them as grounding context for an LLM response. The goal was to build a system that answers accurately from a known, verifiable source rather than hallucinating, and to study where a retrieval-grounded system succeeds and where it breaks down.

## Pipeline

```
User Question
     │
     ▼
Embed Query (all-MiniLM-L6-v2)
     │
     ▼
FAISS Similarity Search (top-3 chunks)
     │
     ▼
Format Retrieved Chunks into Prompt
     │
     ▼
DeepSeek V4 Flash (via OpenRouter) — grounded generation
     │
     ▼
Answer + Source Documents (Gradio UI)
```

## Dataset

- **Primary source:** Top 1,000 C++ questions and their highest-rated answers, pulled from the [StackExchange Data Explorer](https://data.stackexchange.com/stackoverflow/query) via a custom SQL query (`GetStackOverFlowDataset.sql`), refined with help from Gemini to isolate question + best-answer pairs only.
- **Secondary source:** A supplementary C++ Q&A dataset (`CPP_Dataset_MujtabaAhmed.csv`) formatted as prompt/response pairs.
- **Final corpus:** ~5,000 randomly sampled document chunks combined from both sources, used for embedding and retrieval.
- **Known constraint:** StackExchange Data Explorer caps query results at 1,000 rows, which directly limits topic coverage (see [Findings](#evaluation--findings) below).

## Chunking Strategy

Raw Q&A documents were too long for effective retrieval — around 13,000 characters (~5,000 tokens) per document. To fix this:

- Custom character-based chunking function: **600-token chunks (1,200 characters) with 50-token overlap (100 characters)**.
- Each chunk is prefixed with a **header** containing the question title, chunk index, and origin (`QUESTION` or `ANSWER`), so relevance context isn't lost when a document is split across chunks.
- Overlap logic carries the trailing characters of the previous chunk into the next, preserving continuity at chunk boundaries.

## Embeddings & Vector Store

| Component | Choice |
|---|---|
| Embedding model | `all-MiniLM-L6-v2` (sentence-transformers) |
| Vector store | FAISS — `IndexFlatIP` |
| Similarity metric | Cosine similarity (via L2-normalized vectors) |
| Retrieval depth | Top-3 chunks per query |

## Generation (LLM Integration)

- **Model:** DeepSeek V4 Flash
- **Access:** OpenRouter API
- **System prompt design:** Iterated to solve two problems —
  1. The model kept prefacing every answer with filler like *"based only on the documents provided"* — the prompt now explicitly instructs it to answer immediately, since the documents are its reference, not something the user needs restated.
  2. The model needed to distinguish between conversational input (greetings, thanks) and actual C++ questions, answering the former naturally while still refusing anything unrelated to C++ or unsupported by the retrieved documents.

## Evaluation & Findings

Tested against a fixed set of probe questions covering in-domain, edge-case, and out-of-domain queries.

**Finding 1 — Correct but rigid grounding.**
The model correctly refused to answer outside its dataset and avoided hallucination. However, this made it *too* conservative: questions like *"Why would I pick deque over vector?"* — a well-known C++ topic — went unanswered simply because that specific debate wasn't among the top 1,000 highest-rated StackOverflow threads pulled into the dataset.

**Finding 2 — Retrieval works beyond the literal topic.**
The system successfully answered *"do you know who created C++?"* even though that fact wasn't the main subject of any single retrieved document — it was recovered as incidental context within a related answer, showing the retrieval layer generalizes reasonably well within its available data.

**Root cause:** Coverage, not architecture. The 1,000-row StackExchange query limit means simple or less-debated C++ questions are underrepresented in the corpus, so the model has nothing to retrieve for them.

### Proposed Improvement
Extend the corpus with official C++ documentation (e.g., cppreference.com) to cover foundational language topics that aren't well-represented in top-voted StackOverflow threads, without sacrificing the grounding discipline that made the system reliable.

## GUI

Built with **Gradio**:
- Text input for the user's C++ question
- "Load Example Question" button for quick demos
- "Ask" button to submit
- Two output panels: the generated **Answer** and the **Source** documents used to produce it (for transparency/verification)

## Tech Stack

- **Language:** Python
- **Data processing:** Pandas, NumPy
- **Embeddings:** sentence-transformers (`all-MiniLM-L6-v2`)
- **Vector search:** FAISS
- **LLM access:** OpenRouter (DeepSeek V4 Flash)
- **UI:** Gradio
- **Config:** python-dotenv

## Setup & Installation

```bash
# Clone the repo
git clone <repo-url>
cd cpp-assistant

# Install dependencies
pip install pandas numpy sentence-transformers faiss-cpu gradio python-dotenv openrouter

# Set up environment variables
echo "API_KEY=your_openrouter_api_key" > .env
```

## Usage

```bash
python app.py
```

This launches a local Gradio interface (bound to `0.0.0.0` for container/cloud deployment). Enter a C++ question, or click **Load Example Question** to try a sample query, then click **Ask** to see the grounded answer alongside its source documents.

## Limitations

- Retrieval coverage is bounded by the 1,000-row StackOverflow query limit — common but low-vote-count C++ questions may not be answerable.
- No conversation memory; each query is handled independently.
- Grounding is strict by design, so the assistant will decline to answer anything not supported by retrieved context, even if the underlying LLM "knows" the answer.

## Future Work

- Expand beyond the 1,000-row StackExchange limit (e.g., batched queries or an alternative data source)
- Add re-ranking on top of FAISS retrieval for higher-precision context selection

## Author

**Rashed Jafry**
[LinkedIn](https://www.linkedin.com/in/rashed-jafry) · [GitHub](https://github.com/rashid7089)
