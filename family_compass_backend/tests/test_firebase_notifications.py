from __future__ import annotations

import asyncio
from types import SimpleNamespace
from uuid import uuid4

import firebase_admin
from firebase_admin import messaging

from app.models import DevicePlatform, DeviceToken
from app.notification_service import FirebaseNotificationService, NotificationPayload


def _device(index: int) -> DeviceToken:
    return DeviceToken(
        user_id=uuid4(),
        token=f"fcm-registration-token-{index:04d}",
        platform=DevicePlatform.ANDROID,
    )


def _payload() -> NotificationPayload:
    family_id = uuid4()
    resource_id = uuid4()
    return NotificationPayload(
        title="Sensitive plan title",
        body="Sensitive message body that must not appear on a lock screen",
        event_type="plan.created",
        family_id=family_id,
        resource_id=resource_id,
        deep_link=(f"familycompass://families/{family_id}/plans/{resource_id}"),
    )


def test_fcm_uses_generic_lock_screen_copy_and_exact_routing(monkeypatch) -> None:
    sent: list[messaging.MulticastMessage] = []
    monkeypatch.setattr(firebase_admin, "get_app", lambda: object())

    def send(message, *, app):
        assert app is not None
        sent.append(message)
        return SimpleNamespace(
            success_count=len(message.fids),
            failure_count=0,
            responses=[SimpleNamespace(success=True, exception=None)]
            * len(message.fids),
        )

    monkeypatch.setattr(messaging, "send_each_for_multicast", send)
    payload = _payload()

    result = asyncio.run(FirebaseNotificationService().notify([_device(1)], payload))

    assert result.delivered_count == 1
    assert result.failed_count == 0
    assert len(sent) == 1
    message = sent[0]
    assert message.notification.title == "Family Compass"
    assert message.notification.body == "Your family has an update."
    assert payload.title not in message.notification.title
    assert payload.body not in message.notification.body
    assert message.data == {
        "event_type": payload.event_type,
        "family_id": str(payload.family_id),
        "resource_id": str(payload.resource_id),
        "deep_link": payload.deep_link,
    }
    assert message.android.notification.channel_id == "family_updates"
    assert message.apns.headers["apns-push-type"] == "alert"


def test_fcm_splits_multicast_requests_at_500_targets(monkeypatch) -> None:
    batch_sizes: list[int] = []
    monkeypatch.setattr(firebase_admin, "get_app", lambda: object())

    def send(message, *, app):
        assert app is not None
        batch_sizes.append(len(message.fids))
        return SimpleNamespace(
            success_count=len(message.fids),
            failure_count=0,
            responses=[SimpleNamespace(success=True, exception=None)]
            * len(message.fids),
        )

    monkeypatch.setattr(messaging, "send_each_for_multicast", send)

    result = asyncio.run(
        FirebaseNotificationService().notify(
            [_device(index) for index in range(501)],
            _payload(),
        )
    )

    assert batch_sizes == [500, 1]
    assert result.delivered_count == 501
