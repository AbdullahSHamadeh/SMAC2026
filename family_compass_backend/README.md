# Family Compass FastAPI scaffold

This provider-neutral backend scaffold is reserved for Prototype 3. Prototype 2 does not call it.

It currently provides in-memory models, API routes, repositories, seed data, and an AI service boundary that can later connect to OpenAI, LM Studio, vLLM, or another compatible provider.

## Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/docs` for interactive API documentation.

Run tests with:

```bash
PYTHONPATH=. pytest -q
```

Permission checks must happen before any permitted structured family fact reaches an AI provider.
