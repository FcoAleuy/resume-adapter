"""
Unified LLM client with retry.
Supports OpenAI, Groq, and Gemini (all via OpenAI-compatible endpoints).
"""
import asyncio
from backend.config import get_settings

settings = get_settings()

# Provider routing table
_PROVIDERS: dict[str, dict] = {
    "openai": {
        "base_url": None,  # default OpenAI endpoint
        "key_attr": "openai_api_key",
    },
    "groq": {
        "base_url": "https://api.groq.com/openai/v1",
        "key_attr": "groq_api_key",
    },
    "gemini": {
        "base_url": "https://generativelanguage.googleapis.com/v1beta/openai/",
        "key_attr": "gemini_api_key",
    },
}


async def call_llm(
    provider: str,
    model: str,
    system: str,
    user: str,
    json_mode: bool = False,
    temperature: float = 0.2,
) -> str:
    last_error: Exception | None = None
    for attempt in range(settings.max_retries):
        try:
            return await _call_once(provider, model, system, user, json_mode, temperature)
        except Exception as e:
            last_error = e
            if attempt < settings.max_retries - 1:
                await asyncio.sleep(settings.retry_delay_seconds * (attempt + 1))
    raise RuntimeError(f"LLM call failed after {settings.max_retries} attempts: {last_error}") from last_error


async def _call_once(provider, model, system, user, json_mode, temperature) -> str:
    from openai import AsyncOpenAI

    cfg = _PROVIDERS.get(provider)
    if cfg is None:
        raise ValueError(f"Unknown provider '{provider}'. Valid: {list(_PROVIDERS)}")

    api_key = getattr(settings, cfg["key_attr"], "") or ""
    if not api_key:
        raise ValueError(f"API key for provider '{provider}' is not configured.")

    client = AsyncOpenAI(api_key=api_key, base_url=cfg["base_url"])
    kwargs: dict = dict(
        model=model,
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
        temperature=temperature,
    )
    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}

    response = await client.chat.completions.create(**kwargs)
    return response.choices[0].message.content or ""
