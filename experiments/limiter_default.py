"""AnyIO's default thread limiter, as the installed version has it."""
import anyio
from anyio import to_thread


async def tokens() -> float:
    return to_thread.current_default_thread_limiter().total_tokens


print(f"AnyIO default thread limiter: {anyio.run(tokens):g} tokens")
