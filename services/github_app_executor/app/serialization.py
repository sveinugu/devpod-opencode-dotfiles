from __future__ import annotations

from typing import Any


def with_internal_state(base: dict[str, Any], internal_state: dict[str, Any] | None = None) -> dict[str, Any]:
    if not internal_state:
        return base
    labeled = {f"{key} (internal-only)": value for key, value in internal_state.items()}
    return {**base, "internal_state": labeled}
