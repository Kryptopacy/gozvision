"""Semantic retrieval machinery for the GozAI clinical knowledge base.

The curated clinical datasets themselves live in `clinical_corpus`; this
module owns the Gemini embedding client, the on-disk embedding cache, the
in-memory vector index, and semantic search over the corpus. Firebase is
initialized by the caller (tools.py) and passed in as an optional `db` handle.
"""
import hashlib
import json
import os

import numpy as np  # type: ignore
import google.genai as genai  # type: ignore

# Re-exported for backwards compatibility: tests and seed_rag_firestore.py
# import the clinical datasets from this module.
try:
    from .clinical_corpus import (  # noqa: F401
        LOW_VISION_STATS,
        MEDICATION_DATA,
        OPTOMETRY_DATA,
        load_dynamic_documents,
    )
except ImportError:  # standalone-module fallback (IDE analysis paths)
    from clinical_corpus import (  # noqa: F401
        LOW_VISION_STATS,
        MEDICATION_DATA,
        OPTOMETRY_DATA,
        load_dynamic_documents,
    )

# On-disk cache for corpus embeddings, keyed by "<domain>:<key>". Each entry
# stores the sha256 hash of the embedded text alongside the vector so stale
# entries are transparently re-embedded when the corpus text changes.
_EMBEDDING_CACHE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    ".embedding_cache.json",
)


def cosine_similarity(v1, v2):
    """Compute cosine similarity between two 1D normalized vectors."""
    return np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2))


def _load_embedding_cache(path: str = _EMBEDDING_CACHE_PATH) -> dict:
    """Loads the embedding cache from disk; missing/corrupt caches yield {}."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            cache = json.load(f)
        if isinstance(cache, dict):
            return cache
    except Exception:
        pass
    return {}


def _save_embedding_cache(cache: dict, path: str = _EMBEDDING_CACHE_PATH) -> None:
    """Best-effort persistence of the embedding cache; failures are non-fatal."""
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(cache, f)
    except Exception as e:
        print(f"Warning: failed to persist embedding cache: {e}")


class SemanticKnowledgeBase:
    """In-memory RAG database using Gemini embeddings."""

    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(SemanticKnowledgeBase, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self, client=None, db=None):
        """Builds the knowledge base.

        Args:
            client: Optional pre-built `google.genai` client to inject (e.g.
                for tests). When None, falls back to env-based init using
                GEMINI_API_KEY.
            db: Optional Firestore client handle used to merge dynamic RAG
                documents at index time. When None, dynamic loading is skipped
                and only the local clinical corpus is used.
        """
        if self._initialized:
            return

        # Use the injected GenAI client when provided; otherwise try to
        # initialize one (uses GEMINI_API_KEY from env).
        if client is not None:
            self.client = client
        else:
            try:
                api_key = os.environ.get("GEMINI_API_KEY")
                if not api_key:
                    print("CRITICAL: GEMINI_API_KEY environment variable is missing!")
                    self.client = None
                else:
                    self.client = genai.Client(api_key=api_key)
            except Exception as e:
                print(f"Warning: Failed to initialize genai Client: {e}")
                self.client = None

        # Firestore handle for dynamic RAG loading (None skips dynamic loading).
        self.db = db

        # Pinned explicitly — embedding models change the vector space, so
        # "latest" aliases would silently invalidate the cached index.
        # Bumping this triggers a clean rebuild via the model-namespaced cache.
        self.embedding_model = "gemini-embedding-2"

        # Store dicts of {key: embedding}
        self.optometry_embeddings = {}
        self.medication_embeddings = {}
        self.stats_embeddings = {}

        # Store active data sources
        self.optometry_data = OPTOMETRY_DATA.copy()
        self.medication_data = MEDICATION_DATA.copy()
        self.stats_data = LOW_VISION_STATS.copy()

        # Build index if client allows (vectors are cached on disk).
        self._build_index()
        self._initialized = True

    def _embed_with_cache(self, cache_key: str, text_to_embed: str, cache: dict):
        """Returns the embedding vector for `text_to_embed`, backed by the cache.

        Reuses the cached vector when the sha256 of the embedded text matches;
        otherwise calls the embedding API and persists the new vector. The
        cache key is namespaced by model so switching embedding models never
        mixes vectors from different embedding spaces.
        """
        cache_key = f"{self.embedding_model}:{cache_key}"
        text_hash = hashlib.sha256(text_to_embed.encode("utf-8")).hexdigest()
        cached = cache.get(cache_key)
        if (
            isinstance(cached, dict)
            and cached.get("hash") == text_hash
            and isinstance(cached.get("vector"), list)
        ):
            return np.array(cached["vector"])

        response = self.client.models.embed_content(  # type: ignore
            model=self.embedding_model,
            contents=text_to_embed
        )
        values = response.embeddings[0].values
        cache[cache_key] = {
            "hash": text_hash,
            "vector": [float(v) for v in values],
        }
        # Persist after each newly built embedding so partially built indexes
        # are not lost.
        _save_embedding_cache(cache)
        return np.array(values)

    def _build_index(self):
        if not self.client:
            return

        assert self.client is not None

        print("Building SemanticKnowledgeBase index...")

        # Overwrite with any live data from Firestore before embedding
        load_dynamic_documents(self.db, self.optometry_data, self.medication_data, self.stats_data)

        cache = _load_embedding_cache()

        # 1. Embed Optometry Keys
        for condition, info in self.optometry_data.items():
            # Embed a rich description so similarity is high for synonymous queries
            text_to_embed = f"Condition: {condition}. Effects: {info['answer']}"
            try:
                self.optometry_embeddings[condition] = self._embed_with_cache(
                    f"optometry:{condition}", text_to_embed, cache
                )
            except Exception as e:
                print(f"Error embedding optometry data '{condition}': {e}")

        # 2. Embed Medication Keys
        for med, info in self.medication_data.items():
            text_to_embed = f"Medication: {med}. Use: {info['common_use']}. Type: {info['type']}."
            try:
                self.medication_embeddings[med] = self._embed_with_cache(
                    f"medication:{med}", text_to_embed, cache
                )
            except Exception as e:
                print(f"Error embedding medication data '{med}': {e}")

        # 3. Embed Stats Keys
        for stat, info in self.stats_data.items():
            text_to_embed = f"Low Vision Statistic about {stat}: {info['statistic']} {info['context']}"
            try:
                self.stats_embeddings[stat] = self._embed_with_cache(
                    f"statistics:{stat}", text_to_embed, cache
                )
            except Exception as e:
                print(f"Error embedding stats data '{stat}': {e}")

    def semantic_search(self, query: str, domain: str, threshold: float = 0.65):
        """
        Embeds the query and returns the top matching item if above the confidence threshold.
        If it's a 'near miss' (0.55-0.65), it returns a low-confidence flag.
        """
        if not self.client:
            return {"found": False, "error": "GenAI Client not initialized."}

        assert self.client is not None

        # Get query embedding
        try:
            response = self.client.models.embed_content(
                model=self.embedding_model,
                contents=query
            )
            query_vector = np.array(response.embeddings[0].values)
        except Exception as e:
            print(f"Error embedding search query: {e}")
            return {"found": False, "error": str(e)}

        # Choose domain
        if domain == "optometry":
            db = self.optometry_embeddings
            source_data = self.optometry_data
        elif domain == "medication":
            db = self.medication_embeddings
            source_data = self.medication_data
        elif domain == "statistics":
            db = self.stats_embeddings
            source_data = self.stats_data
        else:
            return {"found": False, "error": "Invalid domain."}

        # Find best match
        best_match = None
        best_score = -1.0

        for key, vector in db.items():
            score = cosine_similarity(query_vector, vector)
            if score > best_score:
                best_score = score
                best_match = key

        if best_match:
            if best_score >= threshold:
                print(f"RAG Hit: '{query}' -> '{best_match}' (Score: {best_score:.2f})")
                return {
                    "found": True,
                    "key": best_match,
                    "score": best_score,
                    "data": source_data[best_match]
                }
            elif best_score >= 0.55:
                # Near miss: we found something but it's not perfect.
                # Tell the agent to be cautious or ask for clarification.
                print(f"RAG Near-Miss: '{query}' -> '{best_match}' (Score: {best_score:.2f})")
                return {
                    "found": True,
                    "low_confidence": True,
                    "key": best_match,
                    "score": best_score,
                    "data": source_data[best_match]
                }

        print(f"RAG Miss: '{query}' highest match was '{best_match}' (Score: {best_score:.2f})")
        return {"found": False}
