"""Security and contract tests for the Gemini Live ephemeral-token endpoint."""
from types import SimpleNamespace
from unittest.mock import patch

from fastapi.testclient import TestClient

import serve_production


client = TestClient(serve_production.ADK_APP)


def setup_function() -> None:
    serve_production._token_issued_at.clear()


def test_live_token_rejects_missing_bearer() -> None:
    response = client.post("/gemini/live-token")
    assert response.status_code == 401
    assert response.json()["detail"] == "Missing bearer token"


def test_live_token_mints_constrained_url_for_authenticated_user(monkeypatch) -> None:
    monkeypatch.setenv("GEMINI_API_KEY", "test-server-only-key")
    fake_token = SimpleNamespace(name="auth_tokens/test-token")
    fake_client = SimpleNamespace(
        auth_tokens=SimpleNamespace(create=lambda **_: fake_token),
    )

    with (
        patch.object(serve_production, "_authenticated_user_id", return_value="patient-1"),
        patch.object(serve_production.genai, "Client", return_value=fake_client),
    ):
        response = client.post(
            "/gemini/live-token",
            headers={"Authorization": "Bearer valid-supabase-jwt"},
        )

    assert response.status_code == 200
    payload = response.json()
    assert payload["uses"] == 1
    assert payload["model"] == "models/gemini-3.8-live"
    assert payload["websocket_url"].startswith("wss://")
    assert "BidiGenerateContentConstrained" in payload["websocket_url"]
    assert "access_token=auth_tokens%2Ftest-token" in payload["websocket_url"]
    assert "test-server-only-key" not in response.text


def test_live_token_rate_limit_is_per_authenticated_user() -> None:
    for _ in range(6):
        serve_production._rate_limit_token("patient-1")

    try:
        serve_production._rate_limit_token("patient-1")
    except Exception as exc:
        assert getattr(exc, "status_code", None) == 429
    else:
        raise AssertionError("seventh token mint should be rate-limited")

    # Another authenticated patient has an independent allowance.
    serve_production._rate_limit_token("patient-2")


def test_cors_allows_only_judge_facing_web_origins() -> None:
    allowed = client.options(
        "/gemini/live-token",
        headers={
            "Origin": "https://gozvision.vercel.app",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )
    assert allowed.status_code == 200
    assert allowed.headers["access-control-allow-origin"] == "https://gozvision.vercel.app"

    denied = client.options(
        "/gemini/live-token",
        headers={
            "Origin": "https://untrusted.example",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert denied.status_code == 400
    assert "access-control-allow-origin" not in denied.headers
