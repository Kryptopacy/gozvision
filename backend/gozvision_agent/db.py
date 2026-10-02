"""Shared Supabase service client for the GozVision backend.

Credentials come from the environment (loaded from backend/.env): SUPABASE_URL
and SUPABASE_SERVICE_KEY. The service key bypasses RLS — backend writes are
the trusted path (SOS from the agent, scribe drafts, recall sweeps); all
client-side access goes through RLS instead.
"""
import os

try:
    from dotenv import load_dotenv

    def load_env_files() -> None:
        """Loads backend/.env then the repo-root .env (first wins)."""
        load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
        load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))

    load_env_files()
except Exception:  # pragma: no cover — ambient env without the SDK
    pass

try:
    from supabase import create_client, Client  # type: ignore
except Exception:  # pragma: no cover — ambient env without the SDK
    create_client = None
    Client = None


def service_client():
    """Returns a Supabase client with the service role, or None in stub mode."""
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    if not url or not key or create_client is None:
        return None
    try:
        return create_client(url, key)
    except Exception as e:
        print(f"[GozVision] Supabase client init failed: {e}")
        return None
