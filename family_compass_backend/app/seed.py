from datetime import datetime, timedelta, timezone
from uuid import UUID

from .models import Family, FamilyRole, Journey, MemberStatus, Message, Permission, Reminder, User
from .store import Store

FAMILY_ID = UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
ABDULLAH_ID = UUID("11111111-1111-1111-1111-111111111111")
DAD_ID = UUID("22222222-2222-2222-2222-222222222222")
MOM_ID = UUID("33333333-3333-3333-3333-333333333333")


def seeded_store() -> Store:
    store = Store()
    users = [
        User(id=ABDULLAH_ID, name="Abdullah", phone_number="+971500000001"),
        User(id=DAD_ID, name="Dad", phone_number="+971500000002"),
        User(id=MOM_ID, name="Mom", phone_number="+971500000003"),
    ]
    for user in users:
        store.users.save(user)
    store.families.save(Family(id=FAMILY_ID, name="Compass Family", owner_id=DAD_ID, member_ids=[user.id for user in users]))
    statuses = [
        MemberStatus(user_id=DAD_ID, activity="driving", status="Driving to work", detail="ETA 8:35 AM", battery=78, latitude=25.21, longitude=55.27),
        MemberStatus(user_id=MOM_ID, activity="shopping", status="Grocery shopping", detail="Home in 20 min", battery=92, latitude=25.19, longitude=55.28),
        MemberStatus(user_id=ABDULLAH_ID, activity="university", status="At university", detail="Arrived", battery=61, latitude=25.23, longitude=55.29),
    ]
    for value in statuses:
        store.statuses.save(value)
    store.journeys.save(Journey(family_id=FAMILY_ID, user_id=ABDULLAH_ID, origin="Home", destination="University", eta=datetime.now(timezone.utc) + timedelta(minutes=12), delay_minutes=12))
    store.messages.save(Message(family_id=FAMILY_ID, sender_id=MOM_ID, body="I am going to the supermarket after work."))
    store.reminders.save(Reminder(family_id=FAMILY_ID, title="Family dinner", when="Today · 7:00 PM", assignee="Everyone"))
    for user in users:
        store.permissions.save(Permission(user_id=user.id, family_id=FAMILY_ID, role=FamilyRole.ADMIN if user.id in {DAD_ID, MOM_ID} else FamilyRole.ADULT, can_invite=user.id in {DAD_ID, MOM_ID}))
    return store
