"""Push-notification boundary with local capture and optional Firebase Cloud
Messaging.
"""

from __future__ import annotations

import asyncio
import os
from abc import ABC, abstractmethod
from dataclasses import dataclass
from uuid import UUID

from pydantic import BaseModel, Field

from .models import DeviceToken


class NotificationPayload(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(min_length=1, max_length=240)
    event_type: str = Field(min_length=1, max_length=80)
    family_id: UUID
    resource_id: UUID
    deep_link: str = Field(min_length=1, max_length=1000)


@dataclass(frozen=True)
class NotificationDelivery:
    device_token_id: UUID
    user_id: UUID
    payload: NotificationPayload


@dataclass(frozen=True)
class NotificationDeliveryResult:
    delivered_count: int = 0
    failed_count: int = 0
    invalid_device_token_ids: frozenset[UUID] = frozenset()


class NotificationService(ABC):
    @abstractmethod
    async def notify(
        self,
        devices: list[DeviceToken],
        payload: NotificationPayload,
    ) -> NotificationDeliveryResult:
        raise NotImplementedError


class NotificationServiceUnavailable(RuntimeError):
    """A push provider failed after the application mutation was accepted."""


class InMemoryNotificationService(NotificationService):
    """Safe local provider that captures deliveries without network access."""

    def __init__(self) -> None:
        self.deliveries: list[NotificationDelivery] = []

    async def notify(
        self,
        devices: list[DeviceToken],
        payload: NotificationPayload,
    ) -> NotificationDeliveryResult:
        deliveries = [
            NotificationDelivery(
                device_token_id=device.id,
                user_id=device.user_id,
                payload=payload,
            )
            for device in devices
            if device.enabled
        ]
        self.deliveries.extend(deliveries)
        return NotificationDeliveryResult(delivered_count=len(deliveries))


class FirebaseNotificationService(NotificationService):
    """Optional FCM adapter. Firebase Admin is imported only when selected."""

    async def notify(
        self,
        devices: list[DeviceToken],
        payload: NotificationPayload,
    ) -> NotificationDeliveryResult:
        enabled_devices = [device for device in devices if device.enabled]
        if not enabled_devices:
            return NotificationDeliveryResult()
        try:
            import firebase_admin
            from firebase_admin import messaging
        except ImportError as error:
            raise NotificationServiceUnavailable(
                "FCM is configured but firebase-admin is not installed."
            ) from error
        try:
            firebase_app = firebase_admin.get_app()
        except ValueError:
            firebase_app = firebase_admin.initialize_app()
        delivered_count = 0
        failed_count = 0
        invalid_device_ids: set[UUID] = set()
        try:
            for offset in range(0, len(enabled_devices), 500):
                batch = enabled_devices[offset : offset + 500]
                # Lock-screen text is intentionally generic. The authenticated
                # app fetches the protected message, plan, or reminder after the
                # user opens the exact deep link.
                message = messaging.MulticastMessage(
                    fids=[device.token for device in batch],
                    notification=messaging.Notification(
                        title="Family Compass",
                        body="Your family has an update.",
                    ),
                    data={
                        "event_type": payload.event_type,
                        "family_id": str(payload.family_id),
                        "resource_id": str(payload.resource_id),
                        "deep_link": payload.deep_link,
                    },
                    android=messaging.AndroidConfig(
                        priority="high",
                        notification=messaging.AndroidNotification(
                            channel_id="family_updates",
                            click_action="FLUTTER_NOTIFICATION_CLICK",
                        ),
                    ),
                    apns=messaging.APNSConfig(
                        headers={
                            "apns-priority": "10",
                            "apns-push-type": "alert",
                        },
                        payload=messaging.APNSPayload(
                            aps=messaging.Aps(
                                sound="default",
                                thread_id=f"family-{payload.family_id}",
                            )
                        ),
                    ),
                )
                result = await asyncio.to_thread(
                    messaging.send_each_for_multicast,
                    message,
                    app=firebase_app,
                )
                delivered_count += result.success_count
                failed_count += result.failure_count
                for device, response in zip(batch, result.responses, strict=True):
                    if not response.success and isinstance(
                        response.exception,
                        messaging.UnregisteredError,
                    ):
                        invalid_device_ids.add(device.id)
        except Exception as error:
            raise NotificationServiceUnavailable(
                "FCM could not deliver the notification."
            ) from error
        return NotificationDeliveryResult(
            delivered_count=delivered_count,
            failed_count=failed_count,
            invalid_device_token_ids=frozenset(invalid_device_ids),
        )


def notification_service_from_environment() -> NotificationService:
    provider = (
        os.getenv("FAMILY_COMPASS_NOTIFICATION_PROVIDER", "memory").strip().casefold()
    )
    if provider == "memory":
        return InMemoryNotificationService()
    if provider == "fcm":
        return FirebaseNotificationService()
    raise ValueError(f"Unknown FAMILY_COMPASS_NOTIFICATION_PROVIDER: {provider}")
