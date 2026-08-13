"""Create deterministic Family Compass accounts in the local Auth emulator."""

from __future__ import annotations

import os
from urllib.parse import urlsplit

from .seed import ABDULLAH_ID, DAD_ID, MOM_ID, OUTSIDER_ID

DEMO_PASSWORD = "family-compass-local-only"
DEMO_USERS = (
    (ABDULLAH_ID, "abdullah@family-compass.test", "Abdullah"),
    (DAD_ID, "dad@family-compass.test", "Dad"),
    (MOM_ID, "mom@family-compass.test", "Mom"),
    (OUTSIDER_ID, "noura@family-compass.test", "Noura"),
)


def main() -> None:
    emulator_host = os.getenv("FIREBASE_AUTH_EMULATOR_HOST", "").strip()
    if not _is_loopback_host(emulator_host):
        raise SystemExit(
            "Refusing to seed Firebase outside a loopback Auth emulator. "
            "Set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099."
        )
    project_id = os.getenv("FIREBASE_PROJECT_ID", "demo-family-compass").strip()
    if not project_id.startswith("demo-"):
        raise SystemExit("Use a demo- prefixed Firebase project ID for this helper.")

    try:
        import firebase_admin
        from firebase_admin import auth
    except ImportError as error:
        raise SystemExit(
            "Install requirements-firebase.txt before seeding the emulator."
        ) from error

    try:
        firebase_app = firebase_admin.get_app()
    except ValueError:
        firebase_app = firebase_admin.initialize_app(options={"projectId": project_id})

    for user_id, email, name in DEMO_USERS:
        uid = str(user_id)
        try:
            auth.get_user(uid, app=firebase_app)
            auth.update_user(
                uid,
                email=email,
                password=DEMO_PASSWORD,
                display_name=name,
                app=firebase_app,
            )
        except auth.UserNotFoundError:
            auth.create_user(
                uid=uid,
                email=email,
                password=DEMO_PASSWORD,
                display_name=name,
                app=firebase_app,
            )
        print(f"seeded {email} ({uid})")


def _is_loopback_host(value: str) -> bool:
    if not value or "://" in value:
        return False
    parsed = urlsplit(f"http://{value}")
    return parsed.hostname in {"127.0.0.1", "localhost", "::1"}


if __name__ == "__main__":
    main()
