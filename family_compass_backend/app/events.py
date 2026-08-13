"""Process-local authenticated family event fanout for the development backend."""

from __future__ import annotations

import asyncio
from collections import defaultdict
from collections.abc import Callable
from uuid import UUID

from fastapi import WebSocket

from .models import FamilyEvent


class FamilyEventBus:
    def __init__(self) -> None:
        self._connections: dict[
            UUID, dict[WebSocket, tuple[UUID, Callable[[], int | None]]]
        ] = defaultdict(dict)
        self._lock = asyncio.Lock()

    async def connect(
        self,
        family_id: UUID,
        websocket: WebSocket,
        user_id: UUID,
        authorization_check: Callable[[], int | None],
    ) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[family_id][websocket] = (user_id, authorization_check)

    async def disconnect(self, family_id: UUID, websocket: WebSocket) -> None:
        async with self._lock:
            connections = self._connections.get(family_id)
            if connections is None:
                return
            connections.pop(websocket, None)
            if not connections:
                self._connections.pop(family_id, None)

    async def publish(
        self,
        event: FamilyEvent,
        recipient_ids: set[UUID] | None = None,
    ) -> None:
        async with self._lock:
            connections = tuple(self._connections.get(event.family_id, {}).items())
        stale: list[WebSocket] = []
        payload = event.model_dump(mode="json")
        for websocket, (user_id, authorization_check) in connections:
            if recipient_ids is not None and user_id not in recipient_ids:
                continue
            try:
                close_code = authorization_check()
                if close_code is not None:
                    await websocket.close(code=close_code)
                    stale.append(websocket)
                    continue
                await websocket.send_json(payload)
            except Exception:  # noqa: BLE001
                # Realtime delivery is best-effort. A stale or broken client must
                # never turn an already committed HTTP mutation into a failure.
                stale.append(websocket)
        for websocket in stale:
            await self.disconnect(event.family_id, websocket)
