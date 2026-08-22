import os
import re
import unicodedata
from collections.abc import Callable, Iterable
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from typing import Annotated
from uuid import UUID

from fastapi import (
    Depends,
    FastAPI,
    Header,
    HTTPException,
    Request,
    Response,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from fastapi.middleware.cors import CORSMiddleware

from .ai_service import (
    AIProvider,
    AIProviderUnavailable,
    provider_from_environment,
)
from .auth import (
    AuthCredentials,
    AuthenticationInvalid,
    AuthenticationRequired,
    IdentityProviderUnavailable,
    IdentityVerifier,
    verifier_from_environment,
)
from .database import SqlAlchemyStore
from .events import FamilyEventBus
from .models import (
    AIConsentUpdate,
    AIQuestionScope,
    AIResponse,
    AuthorizedAIRequest,
    AuthorizedFact,
    CheckIn,
    CheckInCreate,
    CompassActionArtifact,
    CompassActionKind,
    CompassFactAudience,
    CompassFactFreshness,
    CompassFactSource,
    CompassRequest,
    CompassUncertainty,
    CompassVisibility,
    DeviceToken,
    DeviceTokenCreate,
    DeviceTokenView,
    Family,
    FamilyCompassArtifact,
    FamilyCompassArtifactKind,
    FamilyCompassExchange,
    FamilyCompassQuestionCreate,
    FamilyCreate,
    FamilyEvent,
    FamilyRole,
    FamilySuggestion,
    IncomingInvitationView,
    Invitation,
    InvitationCreate,
    InvitationState,
    InvitationView,
    Journey,
    JourneyCreate,
    JourneyState,
    JourneyStateUpdate,
    Membership,
    MembershipPermissionUpdate,
    MemberStatus,
    MemberStatusUpsert,
    MemberView,
    Message,
    MessageCreate,
    MessageKind,
    PhoneAccountRegistration,
    Plan,
    PlanCandidateTimeAdd,
    PlanConfirm,
    PlanContribution,
    PlanContributionCreate,
    PlanCreate,
    PlanNudgeResult,
    PlanPhase,
    PlanPublish,
    PlanReminder,
    PlanReminderCreate,
    PlanResponse,
    PlanResponseCreate,
    PublicUser,
    Reminder,
    ReminderCreate,
    ReminderUpdate,
    RsvpChoice,
    SharedUpdate,
    SharedUpdateAudience,
    SharedUpdateCreate,
    SharedUpdateState,
    SharedUpdateStateUpdate,
    TodaySummary,
    User,
    utc_now,
)
from .notification_service import (
    NotificationPayload,
    NotificationService,
    NotificationServiceUnavailable,
    notification_service_from_environment,
)
from .seed import seed_store
from .store import StoreConflict, StoreProtocol

CHAT_CONTEXT_WINDOW = timedelta(days=30)
CHAT_CONTEXT_MESSAGE_LIMIT = 40
CHAT_CONTEXT_KINDS = frozenset(
    {
        MessageKind.TEXT,
        MessageKind.PLAN,
        MessageKind.POLL,
        MessageKind.REMINDER,
    }
)


def create_app(
    store_factory: Callable[[], StoreProtocol] | None = None,
    ai_provider: AIProvider | None = None,
    allow_demo_auth: bool | None = None,
    identity_verifier: IdentityVerifier | None = None,
    database_url: str | None = None,
    seed_development_data: bool | None = None,
    notification_service: NotificationService | None = None,
) -> FastAPI:
    if store_factory is not None:
        store = store_factory()
    else:
        store = SqlAlchemyStore.from_url(database_url)
        should_seed = (
            seed_development_data
            if seed_development_data is not None
            else os.getenv("FAMILY_COMPASS_SEED_DEMO_DATA", "true").casefold() == "true"
        )
        if should_seed:
            seed_store(store)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        try:
            yield
        finally:
            store.close()

    app = FastAPI(
        title="Family Compass API",
        version="0.3.0-dev.1",
        description="Consent-first family coordination API.",
        lifespan=lifespan,
    )
    app.state.store = store
    app.state.ai = (
        ai_provider if ai_provider is not None else provider_from_environment()
    )
    app.state.identity_verifier = (
        identity_verifier
        if identity_verifier is not None
        else verifier_from_environment(allow_demo_auth)
    )
    app.state.events = FamilyEventBus()
    app.state.notifications = (
        notification_service
        if notification_service is not None
        else notification_service_from_environment()
    )
    origins = [
        origin.strip()
        for origin in os.getenv(
            "FAMILY_COMPASS_ALLOWED_ORIGINS",
            "http://127.0.0.1:8080,http://localhost:8080",
        ).split(",")
        if origin.strip()
    ]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_methods=["DELETE", "GET", "POST", "PATCH", "PUT"],
        allow_headers=["Authorization", "Content-Type", "X-Demo-User"],
        allow_credentials=False,
    )

    def get_store(request: Request) -> StoreProtocol:
        return request.app.state.store

    def get_ai(request: Request) -> AIProvider:
        return request.app.state.ai

    def current_user(
        request: Request,
        authorization: Annotated[str | None, Header(alias="Authorization")] = None,
        x_demo_user: Annotated[str | None, Header(alias="X-Demo-User")] = None,
    ) -> User:
        verifier: IdentityVerifier = request.app.state.identity_verifier
        try:
            return _verified_user(
                get_store(request),
                verifier,
                AuthCredentials(
                    authorization=authorization,
                    demo_user=x_demo_user,
                ),
            )
        except IdentityProviderUnavailable as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=str(error),
            ) from error
        except AuthenticationRequired as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=str(error),
                headers={"WWW-Authenticate": "Bearer"},
            ) from error
        except AuthenticationInvalid as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=str(error),
                headers={"WWW-Authenticate": "Bearer"},
            ) from error

        except LookupError as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=str(error),
                headers={"WWW-Authenticate": "Bearer"},
            ) from error

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.post(
        "/api/v1/auth/phone/register",
        response_model=PublicUser,
        status_code=status.HTTP_201_CREATED,
    )
    async def register_phone_account(
        payload: PhoneAccountRegistration,
        request: Request,
        authorization: Annotated[str | None, Header(alias="Authorization")] = None,
        repo: StoreProtocol = Depends(get_store),
    ) -> PublicUser:
        verifier: IdentityVerifier = request.app.state.identity_verifier
        try:
            identity = verifier.verify(AuthCredentials(authorization=authorization))
        except IdentityProviderUnavailable as error:
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                str(error),
            ) from error
        except (AuthenticationRequired, AuthenticationInvalid) as error:
            raise HTTPException(
                status.HTTP_401_UNAUTHORIZED,
                str(error),
                headers={"WWW-Authenticate": "Bearer"},
            ) from error
        if identity.sign_in_provider != "phone" or identity.phone_number is None:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "A Firebase phone-authenticated ID token is required.",
            )
        try:
            user = repo.claim_authenticated_user(
                User(
                    name=payload.name,
                    phone_number=identity.phone_number,
                    auth_subject=identity.subject,
                )
            )
        except StoreConflict as error:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "This phone account is already linked.",
            ) from error
        return _public_user(user)

    @app.get("/api/v1/me", response_model=PublicUser)
    async def me(user: User = Depends(current_user)) -> PublicUser:
        return _public_user(user)

    @app.get("/api/v1/me/device-tokens", response_model=list[DeviceTokenView])
    async def device_tokens(
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[DeviceTokenView]:
        return [
            _device_token_view(device)
            for device in repo.device_tokens.all()
            if device.user_id == user.id
        ]

    @app.post(
        "/api/v1/me/device-tokens",
        response_model=DeviceTokenView,
        status_code=status.HTTP_201_CREATED,
    )
    async def register_device_token(
        payload: DeviceTokenCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> DeviceTokenView:
        try:
            device = repo.claim_device_token(
                DeviceToken(
                    user_id=user.id,
                    token=payload.token,
                    platform=payload.platform,
                )
            )
        except StoreConflict as error:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "This notification installation is already registered to "
                "another account.",
            ) from error
        return _device_token_view(device)

    @app.delete(
        "/api/v1/me/device-tokens/{device_id}",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    async def unregister_device_token(
        device_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Response:
        if not repo.delete_device_token(device_id, user.id):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Device token not found")
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.get("/api/v1/families", response_model=list[Family])
    async def families(
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[Family]:
        family_ids = {
            membership.family_id
            for membership in repo.memberships.all()
            if membership.user_id == user.id
        }
        return [family for family in repo.families.all() if family.id in family_ids]

    @app.get("/api/v1/invitations", response_model=list[IncomingInvitationView])
    async def incoming_invitations(
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[IncomingInvitationView]:
        """Return only actionable invitations addressed to this account."""
        now = utc_now()
        recipient_phone = _phone_digits(user.phone_number)
        matches = sorted(
            (
                invitation
                for invitation in repo.invitations.all()
                if invitation.state == InvitationState.PENDING
                and invitation.expires_at > now
                and _phone_digits(invitation.phone_number) == recipient_phone
                and repo.membership(invitation.family_id, user.id) is None
            ),
            key=lambda invitation: (invitation.created_at, str(invitation.id)),
            reverse=True,
        )
        views: list[IncomingInvitationView] = []
        for invitation in matches:
            family_value = repo.families.get(invitation.family_id)
            inviter = repo.users.get(invitation.invited_by)
            if family_value is None or inviter is None:
                continue
            views.append(
                _incoming_invitation_view(
                    invitation,
                    family=family_value,
                    inviter=inviter,
                )
            )
        return views

    @app.post(
        "/api/v1/families",
        response_model=Family,
        status_code=status.HTTP_201_CREATED,
    )
    async def create_family(
        payload: FamilyCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Family:
        family_value = Family(
            name=payload.name,
            organizer_id=user.id,
            member_ids=[user.id],
        )
        organizer_membership = Membership(
            family_id=family_value.id,
            user_id=user.id,
            role=FamilyRole.ORGANIZER,
            can_invite=True,
        )
        return repo.create_family(family_value, organizer_membership)

    @app.websocket("/api/v1/families/{family_id}/events")
    async def family_events(websocket: WebSocket, family_id: UUID) -> None:
        verifier: IdentityVerifier = websocket.app.state.identity_verifier
        repo: StoreProtocol = websocket.app.state.store
        credentials = AuthCredentials(
            authorization=websocket.headers.get("Authorization"),
            demo_user=websocket.headers.get("X-Demo-User"),
        )
        try:
            user = _verified_user(
                repo,
                verifier,
                credentials,
            )
            _require_membership(repo, family_id, user.id)
        except (AuthenticationRequired, AuthenticationInvalid, LookupError):
            await websocket.close(code=4401)
            return
        except IdentityProviderUnavailable:
            await websocket.close(code=4503)
            return
        except HTTPException:
            await websocket.close(code=4403)
            return

        event_bus: FamilyEventBus = websocket.app.state.events

        def authorization_close_code() -> int | None:
            try:
                verified = _verified_user(repo, verifier, credentials)
                if verified.id != user.id:
                    return 4401
                if repo.membership(family_id, verified.id) is None:
                    return 4403
                return None
            except (
                AuthenticationRequired,
                AuthenticationInvalid,
                LookupError,
            ):
                return 4401
            except IdentityProviderUnavailable:
                return 4503

        await event_bus.connect(
            family_id,
            websocket,
            user.id,
            authorization_close_code,
        )
        await websocket.send_json(
            FamilyEvent(
                family_id=family_id,
                event_type="connected",
                actor_id=user.id,
                resource_id=family_id,
            ).model_dump(mode="json")
        )
        try:
            while True:
                await websocket.receive_text()
        except WebSocketDisconnect:
            pass
        finally:
            await event_bus.disconnect(family_id, websocket)

    @app.get("/api/v1/families/{family_id}", response_model=Family)
    async def family(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Family:
        _require_membership(repo, family_id, user.id)
        return _family_or_404(repo, family_id)

    @app.delete(
        "/api/v1/families/{family_id}",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    async def delete_family(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Response:
        membership = _require_membership(repo, family_id, user.id)
        family_value = _family_or_404(repo, family_id)
        if (
            membership.role != FamilyRole.ORGANIZER
            or family_value.organizer_id != user.id
        ):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Organizer access required")
        repo.delete_family(family_id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="family.deleted",
                actor_id=user.id,
                resource_id=family_id,
            ),
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.get("/api/v1/families/{family_id}/members", response_model=list[MemberView])
    async def family_members(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[MemberView]:
        _require_membership(repo, family_id, user.id)
        return _member_views(repo, _family_or_404(repo, family_id))

    @app.delete(
        "/api/v1/families/{family_id}/members/me",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    async def leave_family(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Response:
        membership = _require_membership(repo, family_id, user.id)
        family_value = _family_or_404(repo, family_id)
        if (
            membership.role == FamilyRole.ORGANIZER
            or family_value.organizer_id == user.id
        ):
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "The organizer must transfer ownership before leaving.",
            )
        updated_family = family_value.model_copy(
            update={
                "member_ids": [
                    member_id
                    for member_id in family_value.member_ids
                    if member_id != user.id
                ]
            }
        )
        repo.remove_family_member(membership.id, updated_family, user.id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="member.left",
                actor_id=user.id,
                resource_id=user.id,
            ),
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.delete(
        "/api/v1/families/{family_id}/members/{member_id}",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    async def remove_family_member(
        family_id: UUID,
        member_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Response:
        actor = _require_membership(repo, family_id, user.id)
        if actor.role != FamilyRole.ORGANIZER:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Organizer access required")
        if member_id == user.id:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Use the leave endpoint after transferring ownership.",
            )
        target = _require_membership(repo, family_id, member_id)
        family_value = _family_or_404(repo, family_id)
        if (
            target.role == FamilyRole.ORGANIZER
            or family_value.organizer_id == member_id
        ):
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "The family organizer cannot be removed.",
            )
        updated_family = family_value.model_copy(
            update={
                "member_ids": [
                    value for value in family_value.member_ids if value != member_id
                ]
            }
        )
        repo.remove_family_member(target.id, updated_family, member_id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="member.removed",
                actor_id=user.id,
                resource_id=member_id,
            ),
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.get(
        "/api/v1/families/{family_id}/permissions",
        response_model=list[MemberView],
    )
    async def permissions(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[MemberView]:
        _require_membership(repo, family_id, user.id)
        return _member_views(repo, _family_or_404(repo, family_id))

    @app.patch(
        "/api/v1/families/{family_id}/permissions/{member_id}",
        response_model=MemberView,
    )
    async def update_permission(
        family_id: UUID,
        member_id: UUID,
        payload: MembershipPermissionUpdate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> MemberView:
        actor = _require_membership(repo, family_id, user.id)
        if actor.role != FamilyRole.ORGANIZER:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Organizer access required")
        target = _require_membership(repo, family_id, member_id)
        updated = repo.memberships.save(
            target.model_copy(update={"can_invite": payload.can_invite})
        )
        target_user = repo.users.get(member_id)
        if not target_user:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Member not found")
        return _member_view(target_user, updated)

    @app.patch(
        "/api/v1/families/{family_id}/me/ai-consent",
        response_model=Membership,
    )
    async def update_ai_consent(
        family_id: UUID,
        payload: AIConsentUpdate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Membership:
        membership = _require_membership(repo, family_id, user.id)
        return repo.memberships.save(
            membership.model_copy(
                update={
                    "allow_external_ai_processing": payload.allow_external_ai_processing
                }
            )
        )

    @app.get(
        "/api/v1/families/{family_id}/invitations",
        response_model=list[InvitationView],
    )
    async def invitations(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[InvitationView]:
        membership = _require_membership(repo, family_id, user.id)
        if not membership.can_invite:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Invite access required")
        return [
            _invitation_view(invitation)
            for invitation in repo.invitations.all()
            if invitation.family_id == family_id
        ]

    @app.post(
        "/api/v1/families/{family_id}/invitations",
        response_model=InvitationView,
        status_code=status.HTTP_201_CREATED,
    )
    async def invite(
        family_id: UUID,
        payload: InvitationCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> InvitationView:
        membership = _require_membership(repo, family_id, user.id)
        if not membership.can_invite:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Invite access required")
        if payload.role == FamilyRole.ORGANIZER:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Invitations cannot assign the organizer role.",
            )
        invitation = repo.invitations.save(
            Invitation(
                family_id=family_id,
                invited_by=user.id,
                phone_number=payload.phone_number,
                role=payload.role,
                expires_at=utc_now() + timedelta(days=7),
            )
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="invitation.created",
                actor_id=user.id,
                resource_id=invitation.id,
                data={"state": invitation.state.value},
            ),
            recipient_ids=_invitation_event_recipient_ids(
                repo,
                invitation,
                actor_id=user.id,
            ),
        )
        return _invitation_view(invitation)

    @app.post(
        "/api/v1/invitations/{invitation_id}/accept",
        response_model=InvitationView,
    )
    async def accept_invitation(
        invitation_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> InvitationView:
        invitation = _invitation_or_404(repo, invitation_id)
        _require_invitation_recipient(invitation, user)
        _require_pending_invitation(invitation)
        family_value = _family_or_404(repo, invitation.family_id)
        if repo.membership(invitation.family_id, user.id):
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "This account is already a family member.",
            )
        new_membership = Membership(
            family_id=invitation.family_id,
            user_id=user.id,
            role=invitation.role,
            can_invite=False,
        )
        updated_family = family_value.model_copy(
            update={"member_ids": [*family_value.member_ids, user.id]}
        )
        try:
            accepted = repo.accept_invitation(
                new_membership,
                updated_family,
                invitation.model_copy(update={"state": InvitationState.ACCEPTED}),
            )
        except StoreConflict as error:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "This invitation is no longer pending.",
            ) from error
        await _publish_event(
            app,
            FamilyEvent(
                family_id=invitation.family_id,
                event_type="invitation.accepted",
                actor_id=user.id,
                resource_id=invitation.id,
                data={"state": accepted.state.value},
            ),
            recipient_ids=_invitation_event_recipient_ids(
                repo,
                accepted,
                actor_id=user.id,
            ),
        )
        return _invitation_view(accepted)

    @app.post(
        "/api/v1/invitations/{invitation_id}/decline",
        response_model=InvitationView,
    )
    async def decline_invitation(
        invitation_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> InvitationView:
        invitation = _invitation_or_404(repo, invitation_id)
        _require_invitation_recipient(invitation, user)
        _require_pending_invitation(invitation)
        declined = repo.invitations.save(
            invitation.model_copy(update={"state": InvitationState.DECLINED})
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=invitation.family_id,
                event_type="invitation.declined",
                actor_id=user.id,
                resource_id=invitation.id,
                data={"state": declined.state.value},
            ),
            recipient_ids=_invitation_event_recipient_ids(
                repo,
                declined,
                actor_id=user.id,
            ),
        )
        return _invitation_view(declined)

    @app.post(
        "/api/v1/families/{family_id}/invitations/{invitation_id}/revoke",
        response_model=InvitationView,
    )
    async def revoke_invitation(
        family_id: UUID,
        invitation_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> InvitationView:
        membership = _require_membership(repo, family_id, user.id)
        invitation = _invitation_or_404(repo, invitation_id, family_id)
        if membership.role != FamilyRole.ORGANIZER and invitation.invited_by != user.id:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the inviter or organizer can revoke this invitation.",
            )
        _require_pending_invitation(invitation)
        revoked = repo.invitations.save(
            invitation.model_copy(update={"state": InvitationState.REVOKED})
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="invitation.revoked",
                actor_id=user.id,
                resource_id=invitation.id,
                data={"state": revoked.state.value},
            ),
            recipient_ids=_invitation_event_recipient_ids(
                repo,
                revoked,
                actor_id=user.id,
            ),
        )
        return _invitation_view(revoked)

    @app.get("/api/v1/families/{family_id}/messages", response_model=list[Message])
    async def messages(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[Message]:
        _require_membership(repo, family_id, user.id)
        values = [
            message for message in repo.messages.all() if message.family_id == family_id
        ]
        return sorted(values, key=lambda message: message.created_at)

    @app.post(
        "/api/v1/families/{family_id}/messages",
        response_model=Message,
        status_code=status.HTTP_201_CREATED,
    )
    async def post_message(
        family_id: UUID,
        payload: MessageCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Message:
        _require_membership(repo, family_id, user.id)
        family_value = _family_or_404(repo, family_id)
        mentioned_member_ids = set(payload.mentioned_member_ids)
        current_member_ids = {
            membership.user_id
            for membership in repo.memberships.all()
            if membership.family_id == family_id
            and membership.user_id in family_value.member_ids
        }
        if not mentioned_member_ids.issubset(current_member_ids):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Mentioned people must be current family members.",
            )
        existing = next(
            (
                message
                for message in repo.messages.all()
                if message.family_id == family_id
                and message.sender_id == user.id
                and message.client_id == payload.client_id
            ),
            None,
        )
        if existing:
            return existing
        message = repo.messages.save(
            Message(
                client_id=payload.client_id,
                family_id=family_id,
                sender_id=user.id,
                body=payload.body,
                mentioned_member_ids=payload.mentioned_member_ids,
            )
        )
        deep_link = _deep_link(family_id, "messages", message.id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="message.created",
                actor_id=user.id,
                resource_id=message.id,
                deep_link=deep_link,
                data={
                    "kind": message.kind.value,
                    "mentioned_member_ids": ",".join(
                        str(member_id) for member_id in message.mentioned_member_ids
                    ),
                },
            ),
        )
        await _notify_family(
            app,
            repo,
            family_id=family_id,
            actor_id=user.id,
            recipient_ids=None,
            payload=NotificationPayload(
                title="New family message",
                body=message.body[:240],
                event_type="message.created",
                family_id=family_id,
                resource_id=message.id,
                deep_link=deep_link,
            ),
        )
        return message

    @app.get(
        "/api/v1/families/{family_id}/shared-updates",
        response_model=list[SharedUpdate],
    )
    async def shared_updates(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[SharedUpdate]:
        _require_membership(repo, family_id, user.id)
        now = utc_now()
        values = [
            update
            for update in repo.shared_updates.all()
            if update.family_id == family_id
            and update.is_active_at(now)
            and update.is_visible_to(user.id)
        ]
        return sorted(values, key=lambda update: update.updated_at, reverse=True)

    @app.post(
        "/api/v1/families/{family_id}/shared-updates",
        response_model=SharedUpdate,
        status_code=status.HTTP_201_CREATED,
    )
    async def create_shared_update(
        family_id: UUID,
        payload: SharedUpdateCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> SharedUpdate:
        family_value = _family_or_404(repo, family_id)
        _require_membership(repo, family_id, user.id)
        now = utc_now()
        _validate_expiry(payload.expires_at, now)
        selected = set(payload.selected_member_ids)
        if payload.audience == SharedUpdateAudience.SELECTED_PEOPLE and not selected:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Choose at least one family member.",
            )
        if payload.audience != SharedUpdateAudience.SELECTED_PEOPLE and selected:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Recipient IDs are only valid for selected people.",
            )
        if not selected.issubset(set(family_value.member_ids)):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Shared-update audiences must be family members.",
            )
        update = repo.shared_updates.save(
            SharedUpdate(
                family_id=family_id,
                subject_user_id=user.id,
                text=payload.text,
                expires_at=payload.expires_at,
                audience=payload.audience,
                selected_member_ids=payload.selected_member_ids,
            )
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="shared_update.created",
                actor_id=user.id,
                resource_id=update.id,
                data={"expires_at": update.expires_at.isoformat()},
            ),
            recipient_ids=_sensitive_recipient_ids(update, family_value),
        )
        return update

    @app.patch(
        "/api/v1/families/{family_id}/shared-updates/{update_id}",
        response_model=SharedUpdate,
    )
    async def change_shared_update_state(
        family_id: UUID,
        update_id: UUID,
        payload: SharedUpdateStateUpdate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> SharedUpdate:
        _require_membership(repo, family_id, user.id)
        family_value = _family_or_404(repo, family_id)
        update = repo.shared_updates.get(update_id)
        if not update or update.family_id != family_id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Shared update not found")
        if update.subject_user_id != user.id:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the person who shared this update can change it.",
            )
        if (
            payload.state is None
            and payload.audience is None
            and payload.selected_member_ids is None
        ):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT, "No change supplied"
            )
        if payload.state == SharedUpdateState.ACTIVE and update.expires_at <= utc_now():
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "An expired update cannot be resumed.",
            )
        audience, selected_member_ids = _resolve_sensitive_audience_update(
            repo,
            family_id,
            user.id,
            update.audience,
            update.selected_member_ids,
            payload.audience,
            payload.selected_member_ids,
        )
        old_recipients = _visible_sensitive_recipient_ids(update, family_value)
        updated = repo.shared_updates.save(
            update.model_copy(
                update={
                    "state": payload.state or update.state,
                    "audience": audience,
                    "selected_member_ids": selected_member_ids,
                    "updated_at": utc_now(),
                }
            )
        )
        await _publish_sensitive_change(
            app,
            family_id=family_id,
            actor_id=user.id,
            resource_id=update_id,
            changed_event_type="shared_update.changed",
            redacted_event_type="shared_update.redacted",
            old_recipients=old_recipients,
            new_recipients=_visible_sensitive_recipient_ids(updated, family_value),
            state=updated.state.value,
        )
        return updated

    @app.get("/api/v1/families/{family_id}/plans", response_model=list[Plan])
    async def plans(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[Plan]:
        _require_membership(repo, family_id, user.id)
        return [
            plan
            for plan in repo.plans.all()
            if plan.family_id == family_id
            and (plan.phase != PlanPhase.DRAFT or plan.coordinator_id == user.id)
        ]

    @app.post(
        "/api/v1/families/{family_id}/plans",
        response_model=Plan,
        status_code=status.HTTP_201_CREATED,
    )
    async def create_plan(
        family_id: UUID,
        payload: PlanCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        family_value = _family_or_404(repo, family_id)
        _require_membership(repo, family_id, user.id)
        existing = repo.plans.get(payload.client_id)
        if existing is not None:
            if existing.family_id == family_id and existing.coordinator_id == user.id:
                return existing
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "That plan request identifier is already in use.",
            )
        _validate_plan_create(payload, family_value, user.id)
        plan_value = repo.plans.save(
            Plan(
                id=payload.client_id,
                family_id=family_id,
                title=payload.title,
                location_label=payload.location_label,
                coordinator_id=user.id,
                participant_ids=payload.participant_ids,
                candidate_times=payload.candidate_times,
                phase=(PlanPhase.POLL_OPEN if payload.publish else PlanPhase.DRAFT),
                decision_deadline=payload.decision_deadline,
            )
        )
        if payload.publish:
            await _announce_plan_poll(app, repo, plan_value, actor_id=user.id)
        return plan_value

    @app.get("/api/v1/families/{family_id}/plans/{plan_id}", response_model=Plan)
    async def plan(
        family_id: UUID,
        plan_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if plan_value.phase == PlanPhase.DRAFT and plan_value.coordinator_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Plan not found")
        return plan_value

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/publish",
        response_model=Plan,
    )
    async def publish_plan(
        family_id: UUID,
        plan_id: UUID,
        payload: PlanPublish,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if plan_value.coordinator_id != user.id:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the coordinator can publish this draft.",
            )
        if plan_value.phase != PlanPhase.DRAFT:
            raise HTTPException(status.HTTP_409_CONFLICT, "This draft is closed.")
        _require_plan_version(plan_value, payload.expected_version)
        candidate_ids = payload.candidate_ids
        if len(set(candidate_ids)) != len(candidate_ids):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Published candidate times must be unique.",
            )
        selected = [
            candidate
            for candidate in plan_value.candidate_times
            if candidate.id in set(candidate_ids)
        ]
        if len(selected) != len(candidate_ids):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Unknown candidate time.",
            )
        published = repo.plans.save(
            plan_value.model_copy(
                update={
                    "candidate_times": selected,
                    "phase": PlanPhase.POLL_OPEN,
                    "version": plan_value.version + 1,
                    "updated_at": utc_now(),
                }
            )
        )
        await _announce_plan_poll(app, repo, published, actor_id=user.id)
        return published

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/candidate-times",
        response_model=Plan,
    )
    async def add_candidate_time(
        family_id: UUID,
        plan_id: UUID,
        payload: PlanCandidateTimeAdd,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if user.id not in plan_value.participant_ids:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not a participant")
        if plan_value.phase != PlanPhase.POLL_OPEN:
            raise HTTPException(status.HTTP_409_CONFLICT, "This poll is closed")
        if plan_value.decision_deadline <= utc_now():
            raise HTTPException(status.HTTP_409_CONFLICT, "This poll has closed")
        _require_plan_version(plan_value, payload.expected_version)
        candidate = payload.candidate_time
        _require_future_time(candidate.starts_at, "Candidate time")
        if candidate.starts_at <= plan_value.decision_deadline:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Candidate times must follow the decision deadline.",
            )
        if candidate.id in {value.id for value in plan_value.candidate_times}:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "That candidate time already exists.",
            )
        updated = repo.plans.save(
            plan_value.model_copy(
                update={
                    "candidate_times": [*plan_value.candidate_times, candidate],
                    "version": plan_value.version + 1,
                    "updated_at": utc_now(),
                }
            )
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="plan.candidate_added",
                actor_id=user.id,
                resource_id=plan_id,
                deep_link=_deep_link(family_id, "plans", plan_id),
                data={"candidate_id": candidate.id, "version": updated.version},
            ),
        )
        return updated

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/reminders",
        response_model=PlanReminder,
        status_code=status.HTTP_201_CREATED,
    )
    async def create_plan_reminder(
        family_id: UUID,
        plan_id: UUID,
        payload: PlanReminderCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> PlanReminder:
        membership = _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if (
            user.id != plan_value.coordinator_id
            and membership.role != FamilyRole.ORGANIZER
        ):
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the coordinator or organizer can add reminders.",
            )
        _require_future_time(payload.at, "Reminder time")
        plan_reminder = PlanReminder(label=payload.label, at=payload.at)
        repo.plans.save(
            plan_value.model_copy(
                update={
                    "reminders": [*plan_value.reminders, plan_reminder],
                    "version": plan_value.version + 1,
                    "updated_at": utc_now(),
                }
            )
        )
        repo.reminders.save(
            Reminder(
                id=plan_reminder.id,
                family_id=family_id,
                created_by=user.id,
                label=payload.label,
                at=payload.at,
                plan_id=plan_id,
            )
        )
        await _emit_reminder_created(
            app, repo, family_id, user.id, plan_value, plan_reminder
        )
        return plan_reminder

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/contributions",
        response_model=Plan,
    )
    async def add_plan_contribution(
        family_id: UUID,
        plan_id: UUID,
        payload: PlanContributionCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if user.id not in plan_value.participant_ids:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not a participant")
        if plan_value.phase in {PlanPhase.COMPLETED, PlanPhase.CANCELLED}:
            raise HTTPException(status.HTTP_409_CONFLICT, "This plan is closed")
        contribution = PlanContribution(member_id=user.id, text=payload.text)
        updated = repo.plans.save(
            plan_value.model_copy(
                update={
                    "contributions": [*plan_value.contributions, contribution],
                    "version": plan_value.version + 1,
                    "updated_at": utc_now(),
                }
            )
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="plan.contribution_added",
                actor_id=user.id,
                resource_id=plan_id,
                deep_link=_deep_link(family_id, "plans", plan_id),
                data={"version": updated.version},
            ),
        )
        return updated

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/responses",
        response_model=Plan,
    )
    async def respond_to_plan(
        family_id: UUID,
        plan_id: UUID,
        payload: PlanResponseCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if user.id not in plan_value.participant_ids:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not a participant")
        if plan_value.phase not in {PlanPhase.POLL_OPEN, PlanPhase.READY_TO_CONFIRM}:
            raise HTTPException(status.HTTP_409_CONFLICT, "This poll is closed")
        if plan_value.decision_deadline <= utc_now():
            raise HTTPException(status.HTTP_409_CONFLICT, "This poll has closed")
        _require_plan_version(plan_value, payload.expected_version)
        if payload.candidate_id not in {
            candidate.id for candidate in plan_value.candidate_times
        }:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT, "Unknown candidate time"
            )
        responses = dict(plan_value.responses)
        responses[user.id] = PlanResponse(
            member_id=user.id,
            candidate_id=payload.candidate_id,
            choice=payload.choice,
        )
        phase = (
            PlanPhase.READY_TO_CONFIRM
            if set(plan_value.participant_ids).issubset(responses)
            else PlanPhase.POLL_OPEN
        )
        updated = repo.plans.save(
            plan_value.model_copy(
                update={
                    "responses": responses,
                    "phase": phase,
                    "version": plan_value.version + 1,
                    "updated_at": utc_now(),
                }
            )
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="plan.response_changed",
                actor_id=user.id,
                resource_id=plan_id,
                deep_link=_deep_link(family_id, "plans", plan_id),
                data={
                    "choice": payload.choice.value,
                    "phase": updated.phase.value,
                    "version": updated.version,
                },
            ),
        )
        return updated

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/confirm",
        response_model=Plan,
    )
    async def confirm_plan(
        family_id: UUID,
        plan_id: UUID,
        payload: PlanConfirm,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        membership = _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if (
            user.id != plan_value.coordinator_id
            and membership.role != FamilyRole.ORGANIZER
        ):
            raise HTTPException(
                status.HTTP_403_FORBIDDEN, "Only the coordinator can confirm"
            )
        if plan_value.phase != PlanPhase.READY_TO_CONFIRM:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Wait for all responses before confirming.",
            )
        _require_plan_version(plan_value, payload.expected_version)
        candidate = next(
            (
                candidate
                for candidate in plan_value.candidate_times
                if candidate.id == payload.candidate_id
            ),
            None,
        )
        if not candidate:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT, "Unknown candidate time"
            )
        if not all(
            response.candidate_id == candidate.id
            and response.choice != RsvpChoice.CANNOT_MAKE_IT
            for response in plan_value.responses.values()
        ):
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "The confirmed time must match every available response.",
            )
        automatic_reminder = PlanReminder(
            label=f"{plan_value.title} starts in one hour",
            at=candidate.starts_at - timedelta(hours=1),
            automatic=True,
        )
        reminders = [
            *plan_value.reminders,
            automatic_reminder,
        ]
        confirmed = repo.plans.save(
            plan_value.model_copy(
                update={
                    "phase": PlanPhase.CONFIRMED,
                    "confirmed_candidate_id": candidate.id,
                    "reminders": reminders,
                    "version": plan_value.version + 1,
                    "updated_at": utc_now(),
                }
            )
        )
        repo.reminders.save(
            Reminder(
                id=automatic_reminder.id,
                family_id=family_id,
                created_by=user.id,
                label=automatic_reminder.label,
                at=automatic_reminder.at,
                plan_id=plan_id,
                automatic=True,
            )
        )
        deep_link = _deep_link(family_id, "plans", plan_id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="plan.confirmed",
                actor_id=user.id,
                resource_id=plan_id,
                deep_link=deep_link,
                data={"phase": confirmed.phase.value, "version": confirmed.version},
            ),
        )
        await _notify_family(
            app,
            repo,
            family_id=family_id,
            actor_id=user.id,
            recipient_ids=set(plan_value.participant_ids),
            payload=NotificationPayload(
                title="Family plan confirmed",
                body=plan_value.title,
                event_type="plan.confirmed",
                family_id=family_id,
                resource_id=plan_id,
                deep_link=deep_link,
            ),
        )
        return confirmed

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/nudge",
        response_model=PlanNudgeResult,
    )
    async def nudge_plan_participants(
        family_id: UUID,
        plan_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> PlanNudgeResult:
        membership = _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if (
            user.id != plan_value.coordinator_id
            and membership.role != FamilyRole.ORGANIZER
        ):
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the coordinator or organizer can send a nudge.",
            )
        recipients = set(plan_value.participant_ids) - set(plan_value.responses)
        recipients.discard(user.id)
        plan_value = repo.claim_plan_nudge(
            plan_id,
            sorted(recipients, key=str),
        )
        if plan_value is None:
            return PlanNudgeResult(notified_member_ids=[])
        recipients = set(plan_value.nudge_recipient_ids)
        deep_link = _deep_link(family_id, "plans", plan_id)
        delivered = await _notify_family(
            app,
            repo,
            family_id=family_id,
            actor_id=user.id,
            recipient_ids=recipients,
            payload=NotificationPayload(
                title="Your reply is needed",
                body=plan_value.title,
                event_type="plan.nudged",
                family_id=family_id,
                resource_id=plan_id,
                deep_link=deep_link,
            ),
        )
        if delivered:
            repo.complete_plan_nudge(plan_id)
        else:
            repo.release_plan_nudge(plan_id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="plan.nudged",
                actor_id=user.id,
                resource_id=plan_id,
                deep_link=deep_link,
                data={"recipient_count": len(recipients)},
            ),
        )
        return PlanNudgeResult(notified_member_ids=sorted(recipients, key=str))

    @app.post(
        "/api/v1/families/{family_id}/plans/{plan_id}/complete",
        response_model=Plan,
    )
    async def complete_plan(
        family_id: UUID,
        plan_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Plan:
        membership = _require_membership(repo, family_id, user.id)
        plan_value = _plan_or_404(repo, family_id, plan_id)
        if (
            user.id != plan_value.coordinator_id
            and membership.role != FamilyRole.ORGANIZER
        ):
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the coordinator or organizer can complete this plan.",
            )
        if plan_value.phase != PlanPhase.CONFIRMED:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Only a confirmed plan can be completed.",
            )
        completed = repo.plans.save(
            plan_value.model_copy(
                update={
                    "phase": PlanPhase.COMPLETED,
                    "version": plan_value.version + 1,
                    "updated_at": utc_now(),
                }
            )
        )
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="plan.completed",
                actor_id=user.id,
                resource_id=plan_id,
                deep_link=_deep_link(family_id, "plans", plan_id),
                data={"phase": completed.phase.value, "version": completed.version},
            ),
        )
        return completed

    @app.get(
        "/api/v1/families/{family_id}/reminders",
        response_model=list[Reminder],
    )
    async def reminders(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[Reminder]:
        _require_membership(repo, family_id, user.id)
        values = [
            reminder
            for reminder in repo.reminders.all()
            if reminder.family_id == family_id
        ]
        return sorted(values, key=lambda reminder: reminder.at)

    @app.post(
        "/api/v1/families/{family_id}/reminders",
        response_model=Reminder,
        status_code=status.HTTP_201_CREATED,
    )
    async def create_reminder(
        family_id: UUID,
        payload: ReminderCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Reminder:
        _require_membership(repo, family_id, user.id)
        _require_future_time(payload.at, "Reminder time")
        plan_value = (
            _plan_or_404(repo, family_id, payload.plan_id) if payload.plan_id else None
        )
        reminder = repo.reminders.save(
            Reminder(
                family_id=family_id,
                created_by=user.id,
                label=payload.label,
                at=payload.at,
                plan_id=payload.plan_id,
            )
        )
        if plan_value:
            plan_reminder = PlanReminder(
                id=reminder.id,
                label=reminder.label,
                at=reminder.at,
            )
            repo.plans.save(
                plan_value.model_copy(
                    update={
                        "reminders": [*plan_value.reminders, plan_reminder],
                        "version": plan_value.version + 1,
                        "updated_at": utc_now(),
                    }
                )
            )
        await _emit_reminder_created(
            app, repo, family_id, user.id, plan_value, reminder
        )
        return reminder

    @app.patch(
        "/api/v1/families/{family_id}/reminders/{reminder_id}",
        response_model=Reminder,
    )
    async def update_reminder(
        family_id: UUID,
        reminder_id: UUID,
        payload: ReminderUpdate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Reminder:
        membership = _require_membership(repo, family_id, user.id)
        reminder = _reminder_or_404(repo, family_id, reminder_id)
        _require_reminder_manager(reminder, membership, user.id)
        changes = payload.model_dump(exclude_none=True)
        if not changes:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "At least one reminder field is required.",
            )
        if payload.at is not None:
            _require_future_time(payload.at, "Reminder time")
        changes["updated_at"] = utc_now()
        updated = repo.reminders.save(reminder.model_copy(update=changes))
        _sync_plan_reminder(repo, updated)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="reminder.updated",
                actor_id=user.id,
                resource_id=reminder_id,
                deep_link=_deep_link(family_id, "reminders", reminder_id),
                data={"completed": updated.completed},
            ),
        )
        return updated

    @app.delete(
        "/api/v1/families/{family_id}/reminders/{reminder_id}",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    async def delete_reminder(
        family_id: UUID,
        reminder_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Response:
        membership = _require_membership(repo, family_id, user.id)
        reminder = _reminder_or_404(repo, family_id, reminder_id)
        _require_reminder_manager(reminder, membership, user.id)
        repo.reminders.delete(reminder_id)
        _remove_plan_reminder(repo, reminder)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="reminder.deleted",
                actor_id=user.id,
                resource_id=reminder_id,
            ),
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.post(
        "/api/v1/families/{family_id}/check-ins",
        response_model=CheckIn,
        status_code=status.HTTP_201_CREATED,
    )
    async def request_check_in(
        family_id: UUID,
        payload: CheckInCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> CheckIn:
        _require_membership(repo, family_id, user.id)
        _require_membership(repo, family_id, payload.subject_user_id)
        if payload.subject_user_id == user.id:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Use a shared update to check yourself in.",
            )
        check_in = repo.check_ins.save(
            CheckIn(
                family_id=family_id,
                requester_id=user.id,
                subject_user_id=payload.subject_user_id,
            )
        )
        deep_link = _deep_link(family_id, "check-ins", check_in.id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="check_in.requested",
                actor_id=user.id,
                resource_id=check_in.id,
                deep_link=deep_link,
                data={"subject_user_id": str(payload.subject_user_id)},
            ),
        )
        await _notify_family(
            app,
            repo,
            family_id=family_id,
            actor_id=user.id,
            recipient_ids={payload.subject_user_id},
            payload=NotificationPayload(
                title="Family check-in",
                body=f"{user.name} asked you to check in.",
                event_type="check_in.requested",
                family_id=family_id,
                resource_id=check_in.id,
                deep_link=deep_link,
            ),
        )
        return check_in

    @app.get(
        "/api/v1/families/{family_id}/statuses",
        response_model=list[MemberStatus],
    )
    async def member_statuses(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[MemberStatus]:
        _require_membership(repo, family_id, user.id)
        now = utc_now()
        _purge_expired_sensitive_context(repo, now)
        return sorted(
            (
                value
                for value in repo.statuses.all()
                if value.family_id == family_id
                and value.is_active_at(now)
                and value.is_visible_to(user.id)
            ),
            key=lambda value: value.updated_at,
            reverse=True,
        )

    @app.put(
        "/api/v1/families/{family_id}/statuses/me",
        response_model=MemberStatus,
    )
    async def share_member_status(
        family_id: UUID,
        payload: MemberStatusUpsert,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> MemberStatus:
        _require_membership(repo, family_id, user.id)
        now = utc_now()
        _validate_expiry(payload.expires_at, now)
        _validate_sensitive_audience(
            repo,
            family_id,
            user.id,
            payload.audience,
            payload.selected_member_ids,
        )
        existing = next(
            (
                value
                for value in repo.statuses.all()
                if value.family_id == family_id
                and value.subject_user_id == user.id
                and value.state == SharedUpdateState.ACTIVE
            ),
            None,
        )
        family_value = _family_or_404(repo, family_id)
        old_recipients = (
            _visible_sensitive_recipient_ids(existing, family_value)
            if existing is not None
            else set()
        )
        value = repo.statuses.save(
            existing.model_copy(
                update={
                    **payload.model_dump(),
                    "updated_at": now,
                }
            )
            if existing
            else MemberStatus(
                family_id=family_id,
                subject_user_id=user.id,
                **payload.model_dump(),
            )
        )
        await _publish_sensitive_change(
            app,
            family_id=family_id,
            actor_id=user.id,
            resource_id=value.id,
            changed_event_type="status.shared",
            redacted_event_type="status.redacted",
            old_recipients=old_recipients,
            new_recipients=_visible_sensitive_recipient_ids(value, family_value),
        )
        return value

    @app.patch(
        "/api/v1/families/{family_id}/statuses/{status_id}",
        response_model=MemberStatus,
    )
    async def change_member_status_state(
        family_id: UUID,
        status_id: UUID,
        payload: SharedUpdateStateUpdate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> MemberStatus:
        _require_membership(repo, family_id, user.id)
        family_value = _family_or_404(repo, family_id)
        value = repo.statuses.get(status_id)
        if not value or value.family_id != family_id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Status not found")
        if value.subject_user_id != user.id:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the person who shared this status can change it.",
            )
        if (
            payload.state is None
            and payload.audience is None
            and payload.selected_member_ids is None
        ):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT, "No change supplied"
            )
        if payload.state == SharedUpdateState.ACTIVE and value.expires_at <= utc_now():
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "An expired status cannot be resumed.",
            )
        audience, selected_member_ids = _resolve_sensitive_audience_update(
            repo,
            family_id,
            user.id,
            value.audience,
            value.selected_member_ids,
            payload.audience,
            payload.selected_member_ids,
        )
        old_recipients = _visible_sensitive_recipient_ids(value, family_value)
        updated = repo.statuses.save(
            value.model_copy(
                update={
                    "state": payload.state or value.state,
                    "audience": audience,
                    "selected_member_ids": selected_member_ids,
                    "updated_at": utc_now(),
                }
            )
        )
        await _publish_sensitive_change(
            app,
            family_id=family_id,
            actor_id=user.id,
            resource_id=status_id,
            changed_event_type="status.changed",
            redacted_event_type="status.redacted",
            old_recipients=old_recipients,
            new_recipients=_visible_sensitive_recipient_ids(updated, family_value),
            state=updated.state.value,
        )
        return updated

    @app.get(
        "/api/v1/families/{family_id}/journeys",
        response_model=list[Journey],
    )
    async def journeys(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[Journey]:
        _require_membership(repo, family_id, user.id)
        now = utc_now()
        _purge_expired_sensitive_context(repo, now)
        return sorted(
            (
                value
                for value in repo.journeys.all()
                if value.family_id == family_id
                and value.is_active_at(now)
                and value.is_visible_to(user.id)
            ),
            key=lambda value: value.updated_at,
            reverse=True,
        )

    @app.post(
        "/api/v1/families/{family_id}/journeys",
        response_model=Journey,
        status_code=status.HTTP_201_CREATED,
    )
    async def share_journey(
        family_id: UUID,
        payload: JourneyCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Journey:
        _require_membership(repo, family_id, user.id)
        now = utc_now()
        _validate_expiry(payload.expires_at, now)
        _validate_sensitive_audience(
            repo,
            family_id,
            user.id,
            payload.audience,
            payload.selected_member_ids,
        )
        if payload.eta is not None and payload.eta.tzinfo is None:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "eta must include a time zone.",
            )
        value = repo.journeys.save(
            Journey(
                family_id=family_id,
                subject_user_id=user.id,
                **payload.model_dump(),
            )
        )
        family_value = _family_or_404(repo, family_id)
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type="journey.shared",
                actor_id=user.id,
                resource_id=value.id,
                data={},
            ),
            recipient_ids=_sensitive_recipient_ids(value, family_value),
        )
        return value

    @app.patch(
        "/api/v1/families/{family_id}/journeys/{journey_id}",
        response_model=Journey,
    )
    async def change_journey_state(
        family_id: UUID,
        journey_id: UUID,
        payload: JourneyStateUpdate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> Journey:
        _require_membership(repo, family_id, user.id)
        family_value = _family_or_404(repo, family_id)
        value = repo.journeys.get(journey_id)
        if not value or value.family_id != family_id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Journey not found")
        if value.subject_user_id != user.id:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Only the person who shared this journey can change it.",
            )
        if (
            payload.state is None
            and payload.audience is None
            and payload.selected_member_ids is None
        ):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT, "No change supplied"
            )
        if payload.state == JourneyState.ACTIVE and value.expires_at <= utc_now():
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "An expired journey cannot be resumed.",
            )
        audience, selected_member_ids = _resolve_sensitive_audience_update(
            repo,
            family_id,
            user.id,
            value.audience,
            value.selected_member_ids,
            payload.audience,
            payload.selected_member_ids,
        )
        old_recipients = _visible_sensitive_recipient_ids(value, family_value)
        updated = repo.journeys.save(
            value.model_copy(
                update={
                    "state": payload.state or value.state,
                    "audience": audience,
                    "selected_member_ids": selected_member_ids,
                    "updated_at": utc_now(),
                }
            )
        )
        await _publish_sensitive_change(
            app,
            family_id=family_id,
            actor_id=user.id,
            resource_id=journey_id,
            changed_event_type="journey.changed",
            redacted_event_type="journey.redacted",
            old_recipients=old_recipients,
            new_recipients=_visible_sensitive_recipient_ids(updated, family_value),
            state=updated.state.value,
        )
        return updated

    @app.get("/api/v1/families/{family_id}/today", response_model=TodaySummary)
    async def today(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> TodaySummary:
        _require_membership(repo, family_id, user.id)
        active_plans = [
            plan
            for plan in repo.plans.all()
            if plan.family_id == family_id
            and plan.phase not in {PlanPhase.CANCELLED, PlanPhase.COMPLETED}
            and (plan.phase != PlanPhase.DRAFT or plan.coordinator_id == user.id)
        ]
        active_plans.sort(key=_plan_start)
        needs_reply = [
            plan
            for plan in active_plans
            if user.id in plan.participant_ids
            and user.id not in plan.responses
            and plan.phase == PlanPhase.POLL_OPEN
        ]
        now = utc_now()
        visible_updates = [
            update
            for update in repo.shared_updates.all()
            if update.family_id == family_id
            and update.is_active_at(now)
            and update.is_visible_to(user.id)
        ]
        suggestion = FamilySuggestion(
            family_id=family_id,
            title="Make Friday easy",
            reason="Two people have already replied to the dinner plan.",
            action_label="Reply to the plan",
        )
        return TodaySummary(
            next_plan=active_plans[0] if active_plans else None,
            needs_reply=needs_reply,
            shared_updates=visible_updates,
            suggestion=suggestion,
        )

    @app.post("/api/v1/families/{family_id}/compass", response_model=AIResponse)
    async def compass(
        family_id: UUID,
        payload: CompassRequest,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
        provider: AIProvider = Depends(get_ai),
    ) -> AIResponse:
        membership = _require_membership(repo, family_id, user.id)
        if payload.visibility != CompassVisibility.PRIVATE:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Compass conversations are private in this version.",
            )
        if (
            provider.uses_external_processing
            and not membership.allow_external_ai_processing
        ):
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "External Compass processing is not enabled for this account.",
            )
        request = _authorized_ai_request(
            repo,
            provider,
            family_id,
            user.id,
            prompt=payload.prompt,
            visibility=payload.visibility,
        )
        try:
            response = await provider.answer(request)
            return _finalize_ai_response(response, request)
        except AIProviderUnavailable as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Compass could not reach the configured AI provider. Try again.",
                headers={"Retry-After": "3"},
            ) from error

    @app.get(
        "/api/v1/families/{family_id}/compass/family-room",
        response_model=list[FamilyCompassArtifact],
    )
    async def family_room_compass_artifacts(
        family_id: UUID,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
    ) -> list[FamilyCompassArtifact]:
        _require_membership(repo, family_id, user.id)
        return sorted(
            (
                artifact
                for artifact in repo.compass_artifacts.all()
                if artifact.family_id == family_id
            ),
            key=lambda artifact: artifact.created_at,
        )

    @app.post(
        "/api/v1/families/{family_id}/compass/family-room",
        response_model=FamilyCompassExchange,
        status_code=status.HTTP_201_CREATED,
    )
    async def ask_compass_in_family_room(
        family_id: UUID,
        payload: FamilyCompassQuestionCreate,
        user: User = Depends(current_user),
        repo: StoreProtocol = Depends(get_store),
        provider: AIProvider = Depends(get_ai),
    ) -> FamilyCompassExchange:
        membership = _require_membership(repo, family_id, user.id)
        prompt = _family_room_prompt(payload.prompt)
        family_value = _family_or_404(repo, family_id)
        current_member_ids = {
            candidate.user_id
            for candidate in repo.memberships.all()
            if candidate.family_id == family_id
            and candidate.user_id in family_value.member_ids
        }
        mentioned_member_ids = set(payload.mentioned_member_ids)
        if not mentioned_member_ids.issubset(current_member_ids):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Mentioned people must be current family members.",
            )
        existing_artifact = repo.compass_artifacts.get(payload.client_id)
        if existing_artifact is not None:
            if (
                existing_artifact.family_id != family_id
                or existing_artifact.requested_by != user.id
            ):
                raise HTTPException(
                    status.HTTP_409_CONFLICT,
                    "That family-room request identifier is already in use.",
                )
            question = repo.messages.get(existing_artifact.request_message_id)
            if (
                question is None
                or question.family_id != family_id
                or question.sender_id != user.id
                or question.client_id != payload.client_id
                or question.kind != MessageKind.COMPASS_QUESTION
                or question.body != payload.prompt
                or question.mentioned_member_ids != payload.mentioned_member_ids
            ):
                raise HTTPException(
                    status.HTTP_409_CONFLICT,
                    "The saved Compass question is incomplete. Use a new request.",
                )
            return FamilyCompassExchange(
                question_message=question,
                artifact=existing_artifact,
            )
        if (
            provider.uses_external_processing
            and not membership.allow_external_ai_processing
        ):
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "External Compass processing is not enabled for this account.",
            )
        requested_question = Message(
            client_id=payload.client_id,
            family_id=family_id,
            sender_id=user.id,
            kind=MessageKind.COMPASS_QUESTION,
            body=payload.prompt,
            mentioned_member_ids=payload.mentioned_member_ids,
        )
        try:
            question, question_created = repo.claim_compass_question(requested_question)
        except StoreConflict as error:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "That family-room request identifier is already in use.",
            ) from error
        deep_link = _deep_link(family_id, "messages", question.id)
        if question_created:
            await _publish_event(
                app,
                FamilyEvent(
                    family_id=family_id,
                    event_type="message.created",
                    actor_id=user.id,
                    resource_id=question.id,
                    deep_link=deep_link,
                    data={
                        "kind": question.kind.value,
                        "mentioned_member_ids": ",".join(
                            str(member_id)
                            for member_id in question.mentioned_member_ids
                        ),
                    },
                ),
            )
            await _notify_family(
                app,
                repo,
                family_id=family_id,
                actor_id=user.id,
                recipient_ids=None,
                payload=NotificationPayload(
                    title="Compass in family chat",
                    body="Compass was mentioned in family chat.",
                    event_type="message.created",
                    family_id=family_id,
                    resource_id=question.id,
                    deep_link=deep_link,
                ),
            )
        request = _authorized_ai_request(
            repo,
            provider,
            family_id,
            user.id,
            prompt=prompt,
            visibility=CompassVisibility.FAMILY_ROOM,
            explicit_subject_id=(
                payload.mentioned_member_ids[0]
                if len(payload.mentioned_member_ids) == 1
                else None
            ),
        )
        try:
            response = _finalize_ai_response(await provider.answer(request), request)
        except AIProviderUnavailable as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Compass could not reach the configured AI provider. Try again.",
                headers={
                    "Retry-After": "3",
                    "X-Compass-Question-Id": str(question.id),
                },
            ) from error

        artifact = FamilyCompassArtifact(
            id=payload.client_id,
            family_id=family_id,
            request_message_id=question.id,
            requested_by=user.id,
            kind=(
                FamilyCompassArtifactKind.SUGGESTION
                if response.action_artifacts
                else FamilyCompassArtifactKind.ANSWER
            ),
            answer=response.answer,
            provider=response.provider,
            grounded_facts=response.grounded_facts,
            actions=response.action_artifacts,
            uncertainty=response.uncertainty,
        )
        try:
            artifact, artifact_created = repo.save_compass_artifact(
                question,
                artifact,
            )
        except StoreConflict as error:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "That family-room request identifier is already in use.",
            ) from error
        if artifact_created:
            await _publish_event(
                app,
                FamilyEvent(
                    family_id=family_id,
                    event_type="compass.artifact.created",
                    actor_id=user.id,
                    resource_id=artifact.id,
                    deep_link=deep_link,
                    data={
                        "kind": artifact.kind.value,
                        "requires_confirmation": any(
                            action.requires_confirmation for action in artifact.actions
                        ),
                    },
                ),
            )
            await _notify_family(
                app,
                repo,
                family_id=family_id,
                actor_id=user.id,
                recipient_ids=None,
                payload=NotificationPayload(
                    title="Compass replied",
                    body="Compass replied in family chat.",
                    event_type="compass.artifact.created",
                    family_id=family_id,
                    resource_id=artifact.id,
                    deep_link=deep_link,
                ),
            )
        return FamilyCompassExchange(
            question_message=question,
            artifact=artifact,
        )

    return app


def _verified_user(
    repo: StoreProtocol,
    verifier: IdentityVerifier,
    credentials: AuthCredentials,
) -> User:
    identity = verifier.verify(credentials)
    user = repo.users.get(identity.user_id) if identity.user_id else None
    if not user:
        user = next(
            (
                candidate
                for candidate in repo.users.all()
                if candidate.auth_subject == identity.subject
            ),
            None,
        )
    if not user:
        raise LookupError("Authenticated account is not registered.")
    _purge_expired_sensitive_context(repo, utc_now())
    return user


async def _publish_event(
    app: FastAPI,
    event: FamilyEvent,
    recipient_ids: set[UUID] | None = None,
) -> None:
    event_bus: FamilyEventBus = app.state.events
    await event_bus.publish(event, recipient_ids=recipient_ids)


async def _publish_sensitive_change(
    app: FastAPI,
    *,
    family_id: UUID,
    actor_id: UUID,
    resource_id: UUID,
    changed_event_type: str,
    redacted_event_type: str,
    old_recipients: set[UUID],
    new_recipients: set[UUID],
    state: str | None = None,
) -> None:
    await _publish_event(
        app,
        FamilyEvent(
            family_id=family_id,
            event_type=changed_event_type,
            actor_id=actor_id,
            resource_id=resource_id,
            data={"state": state} if state is not None else {},
        ),
        recipient_ids=new_recipients,
    )
    former_recipients = old_recipients - new_recipients
    if former_recipients:
        await _publish_event(
            app,
            FamilyEvent(
                family_id=family_id,
                event_type=redacted_event_type,
                actor_id=actor_id,
                resource_id=resource_id,
                data={},
            ),
            recipient_ids=former_recipients,
        )


async def _announce_plan_poll(
    app: FastAPI,
    repo: StoreProtocol,
    plan: Plan,
    *,
    actor_id: UUID,
) -> None:
    deep_link = _deep_link(plan.family_id, "plans", plan.id)
    await _publish_event(
        app,
        FamilyEvent(
            family_id=plan.family_id,
            event_type="plan.created",
            actor_id=actor_id,
            resource_id=plan.id,
            deep_link=deep_link,
            data={"title": plan.title, "phase": plan.phase.value},
        ),
    )
    await _notify_family(
        app,
        repo,
        family_id=plan.family_id,
        actor_id=actor_id,
        recipient_ids=set(plan.participant_ids),
        payload=NotificationPayload(
            title="New family poll",
            body=plan.title,
            event_type="plan.created",
            family_id=plan.family_id,
            resource_id=plan.id,
            deep_link=deep_link,
        ),
    )


async def _notify_family(
    app: FastAPI,
    repo: StoreProtocol,
    *,
    family_id: UUID,
    actor_id: UUID,
    recipient_ids: set[UUID] | None,
    payload: NotificationPayload,
) -> bool:
    family_value = _family_or_404(repo, family_id)
    recipients = (
        set(family_value.member_ids) if recipient_ids is None else set(recipient_ids)
    )
    recipients.intersection_update(family_value.member_ids)
    recipients.discard(actor_id)
    devices = [
        device
        for device in repo.device_tokens.all()
        if device.enabled and device.user_id in recipients
    ]
    notifications: NotificationService = app.state.notifications
    try:
        result = await notifications.notify(devices, payload)
        for device_id in result.invalid_device_token_ids:
            device = repo.device_tokens.get(device_id)
            if device is not None:
                repo.delete_device_token(device.id, device.user_id)
        return True
    except NotificationServiceUnavailable:
        # Push is best-effort. The saved family action and realtime event remain
        # authoritative, and a later worker can retry delivery in production.
        return False


async def _emit_reminder_created(
    app: FastAPI,
    repo: StoreProtocol,
    family_id: UUID,
    actor_id: UUID,
    plan: Plan | None,
    reminder: PlanReminder | Reminder,
) -> None:
    deep_link = _deep_link(family_id, "reminders", reminder.id)
    await _publish_event(
        app,
        FamilyEvent(
            family_id=family_id,
            event_type="reminder.created",
            actor_id=actor_id,
            resource_id=reminder.id,
            deep_link=deep_link,
            data={"label": reminder.label},
        ),
    )
    await _notify_family(
        app,
        repo,
        family_id=family_id,
        actor_id=actor_id,
        recipient_ids=set(plan.participant_ids) if plan else None,
        payload=NotificationPayload(
            title="Family reminder",
            body=reminder.label,
            event_type="reminder.created",
            family_id=family_id,
            resource_id=reminder.id,
            deep_link=deep_link,
        ),
    )


def _deep_link(family_id: UUID, resource: str, resource_id: UUID) -> str:
    return f"familycompass://families/{family_id}/{resource}/{resource_id}"


def _public_user(user: User) -> PublicUser:
    return PublicUser(id=user.id, name=user.name)


def _device_token_view(device: DeviceToken) -> DeviceTokenView:
    return DeviceTokenView(
        id=device.id,
        platform=device.platform,
        enabled=device.enabled,
        created_at=device.created_at,
    )


def _family_or_404(repo: StoreProtocol, family_id: UUID) -> Family:
    family = repo.families.get(family_id)
    if not family:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Family not found")
    return family


def _require_membership(
    repo: StoreProtocol, family_id: UUID, user_id: UUID
) -> Membership:
    _family_or_404(repo, family_id)
    membership = repo.membership(family_id, user_id)
    if not membership:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not a family member")
    return membership


def _member_views(repo: StoreProtocol, family: Family) -> list[MemberView]:
    views: list[MemberView] = []
    for member_id in family.member_ids:
        user = repo.users.get(member_id)
        membership = repo.membership(family.id, member_id)
        if user and membership:
            views.append(_member_view(user, membership))
    return views


def _member_view(user: User, membership: Membership) -> MemberView:
    return MemberView(
        user=_public_user(user),
        role=membership.role,
        can_invite=membership.can_invite,
    )


def _invitation_view(invitation: Invitation) -> InvitationView:
    digits = "".join(
        character for character in invitation.phone_number if character.isdigit()
    )
    suffix = digits[-4:] if digits else ""
    return InvitationView(
        id=invitation.id,
        family_id=invitation.family_id,
        invited_by=invitation.invited_by,
        masked_phone_number=f"•••• {suffix}",
        role=invitation.role,
        state=invitation.state,
        created_at=invitation.created_at,
        expires_at=invitation.expires_at,
    )


def _incoming_invitation_view(
    invitation: Invitation,
    *,
    family: Family,
    inviter: User,
) -> IncomingInvitationView:
    return IncomingInvitationView(
        **_invitation_view(invitation).model_dump(),
        family_name=family.name,
        inviter_name=inviter.name,
    )


def _invitation_event_recipient_ids(
    repo: StoreProtocol,
    invitation: Invitation,
    *,
    actor_id: UUID,
) -> set[UUID]:
    recipients = {
        membership.user_id
        for membership in repo.memberships.all()
        if membership.family_id == invitation.family_id
        and (membership.role == FamilyRole.ORGANIZER or membership.can_invite)
    }
    for participant_id in {actor_id, invitation.invited_by}:
        if repo.membership(invitation.family_id, participant_id) is not None:
            recipients.add(participant_id)
    return recipients


def _invitation_or_404(
    repo: StoreProtocol,
    invitation_id: UUID,
    family_id: UUID | None = None,
) -> Invitation:
    invitation = repo.invitations.get(invitation_id)
    if not invitation or (family_id is not None and invitation.family_id != family_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Invitation not found")
    return invitation


def _require_invitation_recipient(invitation: Invitation, user: User) -> None:
    if _phone_digits(invitation.phone_number) != _phone_digits(user.phone_number):
        raise HTTPException(
            status.HTTP_404_NOT_FOUND,
            "Invitation not found",
        )


def _require_pending_invitation(invitation: Invitation) -> None:
    if invitation.state != InvitationState.PENDING:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "This invitation is no longer pending.",
        )
    if invitation.expires_at <= utc_now():
        raise HTTPException(status.HTTP_409_CONFLICT, "This invitation has expired.")


def _phone_digits(phone_number: str) -> str:
    return "".join(character for character in phone_number if character.isdigit())


def _validate_expiry(expires_at: datetime, now: datetime) -> None:
    if expires_at.tzinfo is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "expires_at must include a time zone.",
        )
    expires_at = expires_at.astimezone(timezone.utc)
    if expires_at <= now:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Shared updates must expire in the future.",
        )
    if expires_at > now + timedelta(hours=24):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Shared updates can last for at most 24 hours.",
        )


def _validate_sensitive_audience(
    repo: StoreProtocol,
    family_id: UUID,
    subject_user_id: UUID,
    audience: SharedUpdateAudience,
    selected_member_ids: list[UUID],
) -> None:
    family_value = _family_or_404(repo, family_id)
    selected = set(selected_member_ids)
    if audience == SharedUpdateAudience.SELECTED_PEOPLE and not selected:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Choose at least one family member.",
        )
    if audience != SharedUpdateAudience.SELECTED_PEOPLE and selected:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Recipient IDs are only valid for selected people.",
        )
    if subject_user_id in selected:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "The person sharing is already included automatically.",
        )
    if not selected.issubset(set(family_value.member_ids)):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Audience recipients must be family members.",
        )


def _sensitive_recipient_ids(
    value: SharedUpdate | MemberStatus | Journey,
    family: Family,
) -> set[UUID]:
    if value.audience == SharedUpdateAudience.WHOLE_FAMILY:
        recipients = set(family.member_ids)
    elif value.audience == SharedUpdateAudience.SELECTED_PEOPLE:
        recipients = set(value.selected_member_ids)
    else:
        recipients = set()
    recipients.add(value.subject_user_id)
    return recipients


def _visible_sensitive_recipient_ids(
    value: SharedUpdate | MemberStatus | Journey,
    family: Family,
) -> set[UUID]:
    now = utc_now()
    if isinstance(value, Journey):
        if not value.is_active_at(now):
            return set()
    elif not value.is_active_at(now):
        return set()
    return _sensitive_recipient_ids(value, family)


def _resolve_sensitive_audience_update(
    repo: StoreProtocol,
    family_id: UUID,
    subject_user_id: UUID,
    current_audience: SharedUpdateAudience,
    current_selected_member_ids: list[UUID],
    requested_audience: SharedUpdateAudience | None,
    requested_selected_member_ids: list[UUID] | None,
) -> tuple[SharedUpdateAudience, list[UUID]]:
    audience = requested_audience or current_audience
    if requested_selected_member_ids is not None:
        selected_member_ids = requested_selected_member_ids
    elif requested_audience is None or requested_audience == current_audience:
        selected_member_ids = current_selected_member_ids
    else:
        selected_member_ids = []
    _validate_sensitive_audience(
        repo,
        family_id,
        subject_user_id,
        audience,
        selected_member_ids,
    )
    return audience, selected_member_ids


def _purge_expired_sensitive_context(
    repo: StoreProtocol,
    now: datetime,
) -> None:
    for value in repo.statuses.all():
        if value.expires_at <= now:
            repo.statuses.delete(value.id)
    for value in repo.journeys.all():
        if value.expires_at <= now:
            repo.journeys.delete(value.id)


def _plan_or_404(repo: StoreProtocol, family_id: UUID, plan_id: UUID) -> Plan:
    plan = repo.plans.get(plan_id)
    if not plan or plan.family_id != family_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Plan not found")
    return plan


def _validate_plan_create(
    payload: PlanCreate,
    family: Family,
    creator_id: UUID,
) -> None:
    participants = payload.participant_ids
    if len(set(participants)) != len(participants):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Plan participants must be unique.",
        )
    if creator_id not in participants:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "The plan coordinator must be a participant.",
        )
    if not set(participants).issubset(family.member_ids):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Plan participants must belong to the family.",
        )
    candidate_ids = [candidate.id for candidate in payload.candidate_times]
    if len(set(candidate_ids)) != len(candidate_ids):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Candidate time IDs must be unique.",
        )
    _require_future_time(payload.decision_deadline, "Decision deadline")
    for candidate in payload.candidate_times:
        _require_future_time(candidate.starts_at, "Candidate time")
        if candidate.starts_at <= payload.decision_deadline:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                "Candidate times must follow the decision deadline.",
            )


def _require_future_time(value: datetime, label: str) -> None:
    if value.tzinfo is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            f"{label} must include a time zone.",
        )
    if value.astimezone(timezone.utc) <= utc_now():
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            f"{label} must be in the future.",
        )


def _reminder_or_404(
    repo: StoreProtocol,
    family_id: UUID,
    reminder_id: UUID,
) -> Reminder:
    reminder = repo.reminders.get(reminder_id)
    if not reminder or reminder.family_id != family_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Reminder not found")
    return reminder


def _require_reminder_manager(
    reminder: Reminder,
    membership: Membership,
    user_id: UUID,
) -> None:
    if reminder.created_by != user_id and membership.role != FamilyRole.ORGANIZER:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Only the reminder creator or organizer can change it.",
        )


def _sync_plan_reminder(repo: StoreProtocol, reminder: Reminder) -> None:
    if not reminder.plan_id:
        return
    plan = repo.plans.get(reminder.plan_id)
    if not plan or plan.family_id != reminder.family_id:
        return
    nested = [
        item.model_copy(update={"label": reminder.label, "at": reminder.at})
        if item.id == reminder.id
        else item
        for item in plan.reminders
    ]
    repo.plans.save(
        plan.model_copy(
            update={
                "reminders": nested,
                "version": plan.version + 1,
                "updated_at": utc_now(),
            }
        )
    )


def _remove_plan_reminder(repo: StoreProtocol, reminder: Reminder) -> None:
    if not reminder.plan_id:
        return
    plan = repo.plans.get(reminder.plan_id)
    if not plan or plan.family_id != reminder.family_id:
        return
    repo.plans.save(
        plan.model_copy(
            update={
                "reminders": [
                    item for item in plan.reminders if item.id != reminder.id
                ],
                "version": plan.version + 1,
                "updated_at": utc_now(),
            }
        )
    )


def _require_plan_version(plan: Plan, expected_version: int) -> None:
    if plan.version != expected_version:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "The plan changed. Refresh before replying.",
        )


def _plan_start(plan: Plan) -> datetime:
    if plan.confirmed_candidate_id:
        confirmed = next(
            (
                candidate.starts_at
                for candidate in plan.candidate_times
                if candidate.id == plan.confirmed_candidate_id
            ),
            None,
        )
        if confirmed:
            return confirmed
    return min(candidate.starts_at for candidate in plan.candidate_times)


def _authorized_facts(
    repo: StoreProtocol,
    provider: AIProvider,
    family_id: UUID,
    requester_id: UUID,
    *,
    visibility: CompassVisibility,
) -> list[AuthorizedFact]:
    now = utc_now()
    facts: list[AuthorizedFact] = []

    def provider_allows(*user_ids: UUID) -> bool:
        memberships = [repo.membership(family_id, user_id) for user_id in set(user_ids)]
        if any(membership is None for membership in memberships):
            return False
        return not provider.uses_external_processing or all(
            membership.allow_external_ai_processing
            for membership in memberships
            if membership is not None
        )

    def room_allows(audience: CompassFactAudience) -> bool:
        return (
            visibility == CompassVisibility.PRIVATE
            or audience == CompassFactAudience.WHOLE_FAMILY
        )

    for update in repo.shared_updates.all():
        if (
            update.family_id != family_id
            or not update.is_active_at(now)
            or not update.is_visible_to(requester_id)
        ):
            continue
        audience = _compass_fact_audience(update.audience)
        if not room_allows(audience) or not provider_allows(update.subject_user_id):
            continue
        subject = repo.users.get(update.subject_user_id)
        if not subject:
            continue
        facts.append(
            AuthorizedFact(
                text=update.text,
                source_id=update.id,
                subject_user_id=update.subject_user_id,
                source_type=CompassFactSource.SHARED_UPDATE,
                source_label=f"{subject.name} shared update",
                audience=audience,
                freshness=CompassFactFreshness.CURRENT,
                updated_at=update.updated_at,
                expires_at=update.expires_at,
            )
        )

    for member_status in repo.statuses.all():
        if (
            member_status.family_id != family_id
            or not member_status.is_active_at(now)
            or not member_status.is_visible_to(requester_id)
        ):
            continue
        audience = _compass_fact_audience(member_status.audience)
        if not room_allows(audience) or not provider_allows(
            member_status.subject_user_id
        ):
            continue
        subject = repo.users.get(member_status.subject_user_id)
        if not subject:
            continue
        detail = f" {member_status.detail}" if member_status.detail else ""
        facts.append(
            AuthorizedFact(
                text=f"{member_status.summary}.{detail}".strip(),
                source_id=member_status.id,
                subject_user_id=member_status.subject_user_id,
                source_type=CompassFactSource.MEMBER_STATUS,
                source_label=f"{subject.name} shared status",
                audience=audience,
                freshness=CompassFactFreshness.CURRENT,
                updated_at=member_status.updated_at,
                expires_at=member_status.expires_at,
            )
        )

    for journey in repo.journeys.all():
        if (
            journey.family_id != family_id
            or not journey.is_active_at(now)
            or not journey.is_visible_to(requester_id)
        ):
            continue
        audience = _compass_fact_audience(journey.audience)
        if not room_allows(audience) or not provider_allows(journey.subject_user_id):
            continue
        subject = repo.users.get(journey.subject_user_id)
        if not subject:
            continue
        eta = f" ETA {journey.eta.isoformat()}." if journey.eta else ""
        facts.append(
            AuthorizedFact(
                text=f"{journey.summary}. Status: {journey.status}.{eta}".strip(),
                source_id=journey.id,
                subject_user_id=journey.subject_user_id,
                source_type=CompassFactSource.JOURNEY,
                source_label=f"{subject.name} shared journey",
                audience=audience,
                freshness=CompassFactFreshness.CURRENT,
                updated_at=journey.updated_at,
                expires_at=journey.expires_at,
            )
        )

    chat_cutoff = now - CHAT_CONTEXT_WINDOW
    recent_chat = sorted(
        (
            message
            for message in repo.messages.all()
            if message.family_id == family_id
            and message.created_at > chat_cutoff
            and message.kind in CHAT_CONTEXT_KINDS
            and provider_allows(message.sender_id)
        ),
        key=lambda message: (message.created_at, str(message.id)),
        reverse=True,
    )[:CHAT_CONTEXT_MESSAGE_LIMIT]
    for message in recent_chat:
        sender = repo.users.get(message.sender_id)
        if sender is None:
            continue
        facts.append(
            AuthorizedFact(
                text=message.body,
                source_id=message.id,
                subject_user_id=message.sender_id,
                source_type=CompassFactSource.CHAT_MESSAGE,
                source_label=f"Family chat message from {sender.name}",
                author_label=sender.name,
                content_kind=message.kind,
                audience=CompassFactAudience.WHOLE_FAMILY,
                freshness=CompassFactFreshness.RECENT,
                updated_at=message.created_at,
                expires_at=message.created_at + CHAT_CONTEXT_WINDOW,
            )
        )

    for plan in repo.plans.all():
        if plan.family_id != family_id or plan.phase in {
            PlanPhase.CANCELLED,
            PlanPhase.COMPLETED,
        }:
            continue
        if plan.phase == PlanPhase.DRAFT and plan.coordinator_id != requester_id:
            continue
        if not provider_allows(*plan.participant_ids):
            continue
        future_candidates = [
            candidate for candidate in plan.candidate_times if candidate.starts_at > now
        ]
        if not future_candidates:
            continue
        if plan.confirmed_candidate_id is not None:
            future_candidates = [
                candidate
                for candidate in future_candidates
                if candidate.id == plan.confirmed_candidate_id
            ]
            if not future_candidates:
                continue
        times = " or ".join(
            _format_candidate(candidate.starts_at) for candidate in future_candidates
        )
        response_parts: list[str] = []
        for response in plan.responses.values():
            member = repo.users.get(response.member_id)
            candidate = next(
                (
                    value
                    for value in plan.candidate_times
                    if value.id == response.candidate_id
                ),
                None,
            )
            if member is None or candidate is None:
                continue
            response_parts.append(
                f"{member.name}: {response.choice.value.replace('_', ' ')} for "
                f"{_format_candidate(candidate.starts_at)}"
            )
        waiting = max(0, len(plan.participant_ids) - len(plan.responses))
        response_text = (
            f" Responses: {'; '.join(response_parts)}. {waiting} waiting."
            if response_parts or waiting
            else ""
        )
        reminder_text = (
            " Reminders: "
            + "; ".join(
                f"{reminder.label} at {_format_candidate(reminder.at)}"
                for reminder in plan.reminders
                if reminder.at > now
            )
            + "."
            if any(reminder.at > now for reminder in plan.reminders)
            else ""
        )
        contribution_text = (
            " Contributions: "
            + "; ".join(contribution.text for contribution in plan.contributions)
            + "."
            if plan.contributions
            else ""
        )
        location_text = (
            f" Location: {plan.location_label}." if plan.location_label else ""
        )
        facts.append(
            AuthorizedFact(
                text=(
                    f"{plan.title} is {plan.phase.value.replace('_', ' ')} for "
                    f"{times}.{location_text}{response_text}{reminder_text}"
                    f"{contribution_text}"
                ).strip(),
                source_id=plan.id,
                source_type=CompassFactSource.PLAN,
                source_label=f"Family plan: {plan.title}",
                audience=CompassFactAudience.WHOLE_FAMILY,
                freshness=CompassFactFreshness.SCHEDULED,
                updated_at=plan.updated_at,
                expires_at=max(candidate.starts_at for candidate in future_candidates)
                + timedelta(days=1),
            )
        )

    for reminder in repo.reminders.all():
        if (
            reminder.family_id != family_id
            or reminder.completed
            or reminder.at <= now
            or not provider_allows(reminder.created_by)
        ):
            continue
        creator = repo.users.get(reminder.created_by)
        creator_label = creator.name if creator is not None else "A family member"
        facts.append(
            AuthorizedFact(
                text=f"{reminder.label} at {_format_candidate(reminder.at)}.",
                source_id=reminder.id,
                source_type=CompassFactSource.REMINDER,
                source_label=f"Family reminder from {creator_label}",
                audience=CompassFactAudience.WHOLE_FAMILY,
                freshness=CompassFactFreshness.SCHEDULED,
                updated_at=reminder.updated_at,
                expires_at=reminder.at + timedelta(days=1),
            )
        )

    if visibility == CompassVisibility.PRIVATE:
        for check_in in repo.check_ins.all():
            expires_at = check_in.created_at + timedelta(days=7)
            if (
                check_in.family_id != family_id
                or requester_id not in {check_in.requester_id, check_in.subject_user_id}
                or expires_at <= now
                or not provider_allows(check_in.requester_id, check_in.subject_user_id)
            ):
                continue
            requester = repo.users.get(check_in.requester_id)
            subject = repo.users.get(check_in.subject_user_id)
            if requester is None or subject is None:
                continue
            facts.append(
                AuthorizedFact(
                    text=(
                        f"{requester.name} requested a check-in from {subject.name}. "
                        f"State: {check_in.state}."
                    ),
                    source_id=check_in.id,
                    subject_user_id=check_in.subject_user_id,
                    source_type=CompassFactSource.CHECK_IN,
                    source_label="Private check-in request",
                    audience=CompassFactAudience.REQUEST_PARTICIPANTS,
                    freshness=CompassFactFreshness.RECENT,
                    updated_at=check_in.created_at,
                    expires_at=expires_at,
                )
            )
    return facts


def _authorized_ai_request(
    repo: StoreProtocol,
    provider: AIProvider,
    family_id: UUID,
    requester_id: UUID,
    *,
    prompt: str,
    visibility: CompassVisibility,
    explicit_subject_id: UUID | None = None,
) -> AuthorizedAIRequest:
    """Build both Compass surfaces from one permission-minimized context path."""
    context_subject_id = explicit_subject_id or _requested_subject_id(
        prompt, repo, family_id, requester_id, include_requester=True
    )
    facts = _facts_for_prompt(
        prompt,
        _authorized_facts(
            repo,
            provider,
            family_id,
            requester_id,
            visibility=visibility,
        ),
        subject_user_id=context_subject_id,
    )
    return AuthorizedAIRequest(
        prompt=prompt,
        visibility=visibility,
        facts=facts,
        requested_subject_id=(
            context_subject_id if context_subject_id != requester_id else None
        ),
        question_scope=_question_scope(
            prompt,
            facts,
            has_named_family_subject=context_subject_id is not None,
        ),
    )


def _facts_for_prompt(
    prompt: str,
    facts: list[AuthorizedFact],
    *,
    subject_user_id: UUID | None,
) -> list[AuthorizedFact]:
    normalized = prompt.casefold()
    if _is_general_context_question(normalized):
        return []
    if (
        subject_user_id is not None
        and _has_subject_retrieval_intent(normalized)
        and not _has_multiple_family_source_intents(normalized)
    ):
        subject_facts = [
            fact for fact in facts if fact.subject_user_id == subject_user_id
        ]
        if _has_location_intent(normalized):
            allowed = {
                CompassFactSource.SHARED_UPDATE,
                CompassFactSource.MEMBER_STATUS,
                CompassFactSource.JOURNEY,
            }
            return _newest_facts(
                fact for fact in subject_facts if fact.source_type in allowed
            )
        if _has_chat_intent(normalized):
            return _rank_relevant_facts(
                normalized,
                [
                    fact
                    for fact in subject_facts
                    if fact.source_type == CompassFactSource.CHAT_MESSAGE
                ],
            )
        source_filter = _single_source_filter(normalized)
        if source_filter is not None:
            subject_facts = [
                fact for fact in subject_facts if fact.source_type in source_filter
            ]
        return _rank_relevant_facts(normalized, subject_facts)

    broad_update_phrases = (
        "what has everyone shared",
        "what did everyone share",
        "family update",
        "family updates",
        "any family update",
        "any update from my family",
        "latest from my family",
        "تحديث العائلة",
        "ماذا شاركت العائلة",
    )
    if any(phrase in normalized for phrase in broad_update_phrases):
        allowed = {
            CompassFactSource.SHARED_UPDATE,
            CompassFactSource.MEMBER_STATUS,
            CompassFactSource.JOURNEY,
        }
        return _newest_facts(fact for fact in facts if fact.source_type in allowed)

    if _has_multiple_family_source_intents(normalized):
        return _rank_relevant_facts(normalized, facts)

    if not _looks_like_family_context_question(normalized):
        return []
    source_filter = _single_source_filter(normalized)
    candidates = (
        facts
        if source_filter is None
        else [fact for fact in facts if fact.source_type in source_filter]
    )
    return _rank_relevant_facts(normalized, candidates)


def _compass_fact_audience(
    audience: SharedUpdateAudience,
) -> CompassFactAudience:
    return {
        SharedUpdateAudience.WHOLE_FAMILY: CompassFactAudience.WHOLE_FAMILY,
        SharedUpdateAudience.SELECTED_PEOPLE: CompassFactAudience.SELECTED_PEOPLE,
        SharedUpdateAudience.SELF_ONLY: CompassFactAudience.SELF_ONLY,
    }[audience]


def _newest_facts(values: Iterable[AuthorizedFact]) -> list[AuthorizedFact]:
    return sorted(values, key=lambda fact: fact.updated_at, reverse=True)[:12]


def _has_multiple_family_source_intents(normalized: str) -> bool:
    intents = (
        any(
            token in normalized
            for token in ("plan", "planned", "poll", "vote", "خطة", "تصويت")
        ),
        any(token in normalized for token in ("reminder", "remind", "تذكير", "ذكرني")),
        _has_chat_intent(normalized),
        any(
            token in normalized
            for token in ("check in", "check-in", "checkin", "اطمئن", "تسجيل وصول")
        ),
        _has_location_intent(normalized) or "status" in normalized,
    )
    return sum(int(intent) for intent in intents) > 1


def _single_source_filter(
    normalized: str,
) -> set[CompassFactSource] | None:
    if _has_chat_intent(normalized):
        return {CompassFactSource.CHAT_MESSAGE}
    if any(token in normalized for token in ("reminder", "remind", "تذكير", "ذكرني")):
        return {CompassFactSource.REMINDER}
    if any(
        token in normalized
        for token in ("check in", "check-in", "checkin", "اطمئن", "تسجيل وصول")
    ):
        return {CompassFactSource.CHECK_IN}
    if _has_location_intent(normalized) or "status" in normalized:
        return {
            CompassFactSource.SHARED_UPDATE,
            CompassFactSource.MEMBER_STATUS,
            CompassFactSource.JOURNEY,
        }
    if any(
        token in normalized
        for token in (
            "plan",
            "planned",
            "dinner",
            "gather",
            "poll",
            "vote",
            "خطة",
            "عشاء",
            "تصويت",
        )
    ):
        return {CompassFactSource.PLAN}
    return None


def _rank_relevant_facts(
    normalized_prompt: str,
    facts: list[AuthorizedFact],
) -> list[AuthorizedFact]:
    query_tokens = _context_tokens(normalized_prompt)
    hinted_sources: set[CompassFactSource] = set()
    if any(
        token in normalized_prompt
        for token in (
            "plan",
            "planned",
            "dinner",
            "gather",
            "poll",
            "reply",
            "replied",
            "response",
            "vote",
            "خطة",
            "عشاء",
            "تصويت",
        )
    ):
        hinted_sources.add(CompassFactSource.PLAN)
    if any(
        token in normalized_prompt for token in ("reminder", "remind", "تذكير", "ذكرني")
    ):
        hinted_sources.add(CompassFactSource.REMINDER)
    if _has_chat_intent(normalized_prompt):
        hinted_sources.add(CompassFactSource.CHAT_MESSAGE)
    if any(
        token in normalized_prompt
        for token in ("check in", "check-in", "checkin", "اطمئن", "تسجيل وصول")
    ):
        hinted_sources.add(CompassFactSource.CHECK_IN)
    if _has_location_intent(normalized_prompt) or "status" in normalized_prompt:
        hinted_sources.update(
            {
                CompassFactSource.SHARED_UPDATE,
                CompassFactSource.MEMBER_STATUS,
                CompassFactSource.JOURNEY,
            }
        )

    ranked: list[tuple[int, datetime, AuthorizedFact]] = []
    for fact in facts:
        fact_tokens = _context_tokens(f"{fact.source_label} {fact.text}")
        overlap = len(query_tokens & fact_tokens)
        score = overlap * 3
        if fact.source_type in hinted_sources:
            score += 8
        if score:
            ranked.append((score, fact.updated_at, fact))
    ranked.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [item[2] for item in ranked[:12]]


def _context_tokens(value: str) -> set[str]:
    stop_words = {
        "a",
        "about",
        "are",
        "did",
        "do",
        "does",
        "for",
        "from",
        "has",
        "have",
        "i",
        "in",
        "is",
        "it",
        "me",
        "my",
        "of",
        "on",
        "our",
        "the",
        "to",
        "us",
        "we",
        "what",
        "when",
        "where",
        "who",
        "will",
    }
    return {
        token
        for token in re.findall(r"[^\W_]+", value.casefold(), flags=re.UNICODE)
        if len(token) > 1 and token not in stop_words
    }


def _looks_like_family_context_question(normalized: str) -> bool:
    if _family_subject(normalized) is not None:
        return True
    if _has_explicit_family_retrieval_intent(_classifier_text(normalized)):
        return True
    explicit_phrases = (
        "my family",
        "our family",
        "family update",
        "family status",
        "family plans",
        "our reminder",
        "my reminder",
        "reminders do we",
        "reminders are coming",
        "do we have",
        "did we decide",
        "have we decided",
        "what did we",
        "what are we",
        "check in",
        "check-in",
        "our chat",
        "family chat",
        "عائلتي",
        "عائلتنا",
        "خطة العائلة",
        "تذكير العائلة",
        "محادثة العائلة",
    )
    if any(phrase in normalized for phrase in explicit_phrases):
        return True
    if not _mentions_family_plan(normalized):
        return False
    return any(
        phrase in normalized
        for phrase in (
            "our ",
            "my ",
            "we ",
            " us ",
            "the family",
            "the dinner",
            "when is",
            "did we",
            "have we",
            "help us",
            "can you",
            "tonight",
            "tomorrow",
            "friday",
            "saturday",
            "sunday",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "عائلتنا",
            "خطتنا",
        )
    )


def _has_location_intent(normalized: str) -> bool:
    return any(
        phrase in normalized
        for phrase in (
            "where",
            "eta",
            "arrive",
            "arrival",
            "on the way",
            "running late",
            "what is dad doing",
            "what's dad doing",
            "what is mom doing",
            "what's mom doing",
            "أين",
            "اين",
            "متى سيصل",
            "متأخر",
            "في الطريق",
            "حالة",
        )
    )


def _has_chat_intent(normalized: str) -> bool:
    return any(
        phrase in normalized
        for phrase in (
            "say",
            "said",
            "tell us",
            "told us",
            "message",
            "chat",
            "mention",
            "mentioned",
            "discuss",
            "discussed",
            "talked about",
            "conversation",
            "catch me up",
            "what did i miss",
            "كتب",
            "قال",
            "ذكر",
            "ناقش",
            "رسالة",
            "محادثة",
        )
    )


def _has_subject_retrieval_intent(value: str) -> bool:
    """Identify requests for stored facts about one explicitly named member."""
    normalized = _classifier_text(value)
    if _has_location_intent(normalized):
        return True
    if any(
        phrase in normalized
        for phrase in (
            "current status",
            "latest update",
            "shared update",
            "what has",
            "what did",
            "tell me what",
            "tell us what",
            "message from",
            "messages from",
            "latest message",
            "summarize",
            "catch me up",
            "ماذا قال",
            "ماذا قالت",
            "ماذا كتب",
            "ماذا كتبت",
            "رسالة من",
            "رسايل من",
            "اخر رسالة",
            "لخص",
        )
    ):
        return True
    return bool(
        re.search(
            r"\b(?:did|has)\b.{0,80}\b(?:say|said|share|shared|write|wrote|mention|mentioned)\b",
            normalized,
        )
    )


def _family_room_prompt(value: str) -> str:
    mention = re.compile(
        r"(?<![\w@])@compass(?![\w])",
        flags=re.IGNORECASE,
    )
    if mention.search(value) is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Family-room Compass questions must mention @Compass.",
        )
    prompt = mention.sub(" ", value)
    prompt = re.sub(r"\s+", " ", prompt).strip()
    prompt = re.sub(r"^[,،:：-]+\s*", "", prompt)
    prompt = re.sub(r"([,،:：-])\s*[,،:：-]\s*", r"\1 ", prompt)
    prompt = re.sub(r"\s+([?!.,،:؛؟])", r"\1", prompt)
    if not prompt or not re.search(r"[^\W_]", prompt, flags=re.UNICODE):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "Ask Compass a question after mentioning it.",
        )
    return prompt


def _requested_subject_id(
    prompt: str,
    repo: StoreProtocol,
    family_id: UUID,
    requester_id: UUID,
    *,
    include_requester: bool = False,
) -> UUID | None:
    """Resolve one current family member named explicitly in the prompt.

    Names come only from current memberships. Relationship aliases are retained
    for families that use labels such as ``Dad`` or ``Mom`` as display names,
    but an alias is never guessed from age, role, or message content.
    """
    normalized = _classifier_text(prompt)
    members = [
        repo.users.get(membership.user_id)
        for membership in repo.memberships.all()
        if membership.family_id == family_id
        and (include_requester or membership.user_id != requester_id)
    ]
    members = [member for member in members if member is not None]
    explicit = []
    for member in members:
        normalized_name = _classifier_text(member.name)
        if len(normalized_name) >= 2 and _contains_subject_term(
            normalized,
            normalized_name,
        ):
            explicit.append(member)
    if len(explicit) == 1:
        return explicit[0].id
    if explicit:
        grammatical_matches = [
            member
            for member in explicit
            if _subject_term_has_retrieval_grammar(
                normalized,
                _classifier_text(member.name),
            )
        ]
        if len(grammatical_matches) == 1:
            return grammatical_matches[0].id
        return None

    relationship_aliases = {
        "dad": ("dad", "father", "بابا", "أبي", "ابي", "والدي"),
        "mom": ("mom", "mum", "mother", "ماما", "أمي", "امي", "والدتي"),
    }
    for relationship, aliases in relationship_aliases.items():
        normalized_aliases = tuple(_classifier_text(alias) for alias in aliases)
        if not any(
            _contains_subject_term(normalized, alias) for alias in normalized_aliases
        ):
            continue
        matches = [
            member
            for member in members
            if _contains_subject_term(
                _classifier_text(member.name),
                relationship,
            )
            or _classifier_text(member.name) in normalized_aliases
        ]
        if len(matches) == 1:
            return matches[0].id
    return None


def _contains_subject_term(value: str, term: str) -> bool:
    """Match a Unicode name or alias without accepting partial-word hits."""
    flexible_term = r"\s+".join(re.escape(part) for part in term.split())
    return re.search(rf"(?<!\w){flexible_term}(?!\w)", value) is not None


def _subject_term_has_retrieval_grammar(value: str, term: str) -> bool:
    flexible_term = r"\s+".join(re.escape(part) for part in term.split())
    before_subject = (
        r"(?:what\s+(?:did|has|is)|tell\s+(?:me|us)\s+what|where\s+is|"
        r"where's|when\s+will|status\s+of|messages?\s+from|"
        r"latest\s+messages?\s+from|ماذا\s+(?:قال|قالت|كتب|كتبت)|"
        r"رسالة\s+من|اين|أين|حالة)"
    )
    return (
        re.search(
            rf"{before_subject}\s+{flexible_term}(?!\w)",
            value,
        )
        is not None
    )


def _finalize_ai_response(
    response: AIResponse,
    request: AuthorizedAIRequest,
) -> AIResponse:
    grounded = (
        request.facts
        if request.question_scope == AIQuestionScope.FAMILY_GROUNDED
        else []
    )
    uncertainty = response.uncertainty
    if request.question_scope == AIQuestionScope.FAMILY_WITHOUT_CONTEXT:
        uncertainty = CompassUncertainty.HIGH
    elif request.question_scope == AIQuestionScope.GENERAL:
        uncertainty = CompassUncertainty.NOT_APPLICABLE
    elif uncertainty not in {CompassUncertainty.LOW, CompassUncertainty.MEDIUM}:
        uncertainty = CompassUncertainty.MEDIUM
    action_labels = [
        *response.suggested_actions,
        *_backend_action_labels(request),
    ]
    actions = (
        []
        if request.question_scope == AIQuestionScope.GENERAL
        else _safe_action_artifacts(
            action_labels,
            grounded,
            requested_subject_id=request.requested_subject_id,
        )
    )
    return response.model_copy(
        update={
            "answer": response.answer[:8000],
            "grounded_facts": grounded,
            "suggested_actions": [action.label for action in actions],
            "action_artifacts": actions,
            "has_permitted_information": bool(grounded),
            "answer_kind": request.question_scope,
            "audience": request.visibility,
            "uncertainty": uncertainty,
        }
    )


def _safe_action_artifacts(
    labels: list[str],
    facts: list[AuthorizedFact],
    *,
    requested_subject_id: UUID | None = None,
) -> list[CompassActionArtifact]:
    plan = next(
        (fact for fact in facts if fact.source_type == CompassFactSource.PLAN),
        None,
    )
    subject = next(
        (fact.subject_user_id for fact in facts if fact.subject_user_id is not None),
        requested_subject_id,
    )
    actions: list[CompassActionArtifact] = []
    seen: set[CompassActionKind] = set()
    for value in labels:
        normalized = value.casefold()
        action: CompassActionArtifact | None = None
        if "open" in normalized and "plan" in normalized and plan is not None:
            action = CompassActionArtifact(
                kind=CompassActionKind.OPEN_PLAN,
                label="Open the family plan",
                requires_confirmation=False,
                target_id=plan.source_id,
            )
        elif (
            plan is None
            and "plan" in normalized
            and any(word in normalized for word in ("start", "create", "draft"))
        ):
            action = CompassActionArtifact(
                kind=CompassActionKind.START_PLAN,
                label="Start a family plan",
            )
        elif any(
            phrase in normalized for phrase in ("check-in", "check in", "checkin")
        ):
            action = CompassActionArtifact(
                kind=CompassActionKind.REQUEST_CHECK_IN,
                label="Request a check-in",
                target_id=subject,
            )
        elif "remind" in normalized:
            action = CompassActionArtifact(
                kind=CompassActionKind.CREATE_REMINDER,
                label="Create a reminder",
            )
        if action is not None and action.kind not in seen:
            actions.append(action)
            seen.add(action.kind)
    return actions


def _backend_action_labels(request: AuthorizedAIRequest) -> list[str]:
    normalized = request.prompt.casefold()
    if request.question_scope == AIQuestionScope.FAMILY_GROUNDED and any(
        fact.source_type == CompassFactSource.PLAN for fact in request.facts
    ):
        return ["Open the family plan"]
    if request.question_scope != AIQuestionScope.FAMILY_WITHOUT_CONTEXT:
        return []
    if _mentions_family_plan(normalized):
        return ["Start a family plan"]
    if request.requested_subject_id is not None and _has_location_intent(normalized):
        return ["Request a check-in"]
    if "remind" in normalized or "تذكير" in normalized:
        return ["Create a reminder"]
    return []


def _question_scope(
    prompt: str,
    facts: list[AuthorizedFact],
    *,
    has_named_family_subject: bool = False,
) -> AIQuestionScope:
    if facts:
        return AIQuestionScope.FAMILY_GROUNDED
    normalized = prompt.casefold()
    if _is_general_context_question(normalized):
        return AIQuestionScope.GENERAL
    family_phrases = (
        "my family",
        "our family",
        "family update",
        "family plan",
        "family dinner",
        "dinner plan",
        "our dinner",
        "family gathering",
        "get together",
        "our plan",
        "what has everyone shared",
        "our reminder",
        "my reminder",
        "reminders do we",
        "check in",
        "check-in",
        "our chat",
        "family chat",
        "where is my",
        "when will my",
        "أين أبي",
        "اين ابي",
        "أين والدي",
        "اين والدي",
        "أين ابوي",
        "اين ابوي",
        "متى سيصل أبي",
        "متى سيصل ابي",
        "أين أمي",
        "اين امي",
        "أين والدتي",
        "اين والدتي",
        "متى ستصل أمي",
        "متى ستصل امي",
        "عائلتي",
        "عائلتنا",
        "خطة العائلة",
        "تحديث العائلة",
    )
    if (
        _family_subject(normalized) is not None
        or (has_named_family_subject and _has_subject_retrieval_intent(normalized))
        or _looks_like_family_context_question(normalized)
        or any(phrase in normalized for phrase in family_phrases)
    ):
        return AIQuestionScope.FAMILY_WITHOUT_CONTEXT
    return AIQuestionScope.GENERAL


def _mentions_family_plan(normalized: str) -> bool:
    return any(
        phrase in normalized
        for phrase in (
            "family dinner",
            "dinner plan",
            "our dinner",
            "family gathering",
            "get together",
            "family plan",
            "family plans",
            "our plan",
            "عشاء العائلة",
            "خطة العشاء",
            "نتجمع",
            "نجتمع",
            "خطتنا",
            "خطة العائلة",
        )
    )


def _is_general_family_planning_question(normalized: str) -> bool:
    compact = normalized.strip().rstrip("?.!").strip()
    return compact in {
        "what is family planning",
        "define family planning",
        "explain family planning",
        "ما هو تنظيم الأسرة",
        "ما هو تنظيم الاسرة",
    }


def _is_general_context_question(normalized: str) -> bool:
    compact = normalized.strip().rstrip("?.!").strip()
    return (
        _is_general_family_planning_question(normalized)
        or _is_general_family_advice_question(normalized)
        or compact
        in {
            "what is a family gathering",
            "define family gathering",
            "explain family gathering",
            "what is a family dinner",
            "what is a reminder",
            "define reminder",
            "what is a check-in",
            "what is a check in",
            "define check-in",
            "ما هو التجمع العائلي",
            "ما هو تذكير",
            "ما هو تسجيل الوصول",
        }
    )


def _is_general_family_advice_question(value: str) -> bool:
    """Separate creative family advice from questions about stored family state.

    Words such as ``family`` and ``tonight`` are not evidence that the requester
    wants the current family plan. Retrieval and explicit action language take
    priority; otherwise strong advice and activity-idea language stays general
    and receives no family facts.
    """

    normalized = _classifier_text(value)
    if _has_explicit_family_retrieval_intent(normalized):
        return False
    if _has_explicit_family_action_intent(normalized):
        return False
    advice_phrases = (
        "give my family an idea",
        "give our family an idea",
        "give the family an idea",
        "give us an idea",
        "suggest an idea",
        "suggest something",
        "suggest a family activity",
        "suggest family activities",
        "recommend an activity",
        "recommend something",
        "any ideas",
        "some ideas",
        "activity idea",
        "activity ideas",
        "family activities",
        "family activity",
        "ways to spend time",
        "tips for spending time",
        "how can we spend time",
        "how should we spend time",
        "what can we do together",
        "what should we do together",
        "what can our family do",
        "what should our family do",
        "where can our family go",
        "where should our family go",
        "good place for our family",
        "things to do together",
        "spend time together",
        "spending time together",
        "family bonding",
        "bond as a family",
        "something fun to do",
        "something warm to do",
        "اعط عائلتي فكرة",
        "اعط عائلتنا فكرة",
        "اعطنا فكرة",
        "اقترح فكرة",
        "اقترح نشاط",
        "اقترح انشطة",
        "فكرة عائلية",
        "افكار عائلية",
        "نشاط عائلي",
        "انشطة عائلية",
        "نصيحة لقضاء وقت",
        "نصائح لقضاء وقت",
        "كيف نقضي وقت",
        "ماذا يمكننا ان نفعل معا",
        "ماذا نفعل معا",
        "لقضاء وقت معا",
        "نقضي وقتا معا",
        "وقت معا كعائلة",
        "نتقارب كعائلة",
    )
    return _has_classifier_phrase(normalized, advice_phrases) or bool(
        re.search(
            r"\b(?:give|suggest|recommend)\b.{0,80}"
            r"\b(?:idea|activity|activities|something to do)\b",
            normalized,
        )
    )


def _has_explicit_family_retrieval_intent(normalized: str) -> bool:
    retrieval_phrases = (
        "what is the eta",
        "what's the eta",
        "running late",
        "on the way",
        "latest family update",
        "latest family updates",
        "what has everyone shared",
        "what did everyone share",
        "our family status",
        "current status",
        "status of dad",
        "status of mom",
        "our chat",
        "family chat",
        "what did dad say",
        "what did mom say",
        "what dad said",
        "what mom said",
        "what has dad shared",
        "what has mom shared",
        "message from dad",
        "message from mom",
        "our reminder",
        "our reminders",
        "my reminder",
        "my reminders",
        "what reminders",
        "when is the reminder",
        "what is our plan",
        "what's our plan",
        "what are our plans",
        "when is our plan",
        "when is the family dinner",
        "what time is the family dinner",
        "what family plans are active",
        "did we decide",
        "have we decided",
        "what did we decide",
        "what are we doing tonight",
        "what is our family doing tonight",
        "based on our plan",
        "based on the family plan",
        "in our plan",
        "from our plan",
        "our current plan",
        "what is planned",
        "planned for",
        "scheduled for",
        "plan poll",
        "poll responses",
        "poll replies",
        "متى سيصل",
        "في الطريق",
        "متاخر",
        "اخر تحديث للعائلة",
        "تحديثات العائلة",
        "حالة ابي",
        "حالة امي",
        "ماذا شارك الجميع",
        "ماذا قال ابي",
        "ماذا قالت امي",
        "محادثة العائلة",
        "رسالة من ابي",
        "رسالة من امي",
        "تذكيرنا",
        "تذكيراتنا",
        "ما هي تذكيراتنا",
        "متى التذكير",
        "ما خطتنا",
        "ما هي خطتنا",
        "متى خطتنا",
        "متى عشاء العائلة",
        "هل قررنا",
        "ماذا قررنا",
        "ماذا سنفعل الليلة",
        "بناء على خطتنا",
        "حسب خطتنا",
        "في خطتنا",
        "خطتنا الحالية",
        "المخطط له",
        "قررنا",
        "تصويت الخطة",
        "ردود التصويت",
    )
    return _has_classifier_phrase(normalized, retrieval_phrases)


def _has_explicit_family_action_intent(normalized: str) -> bool:
    action_phrases = (
        "start a family plan",
        "create a family plan",
        "draft a family plan",
        "schedule a family",
        "organize a family",
        "help us start a family",
        "help us plan a family",
        "create a reminder",
        "set a reminder",
        "remind us",
        "request a check-in",
        "ask dad to check in",
        "ask mom to check in",
        "ابدأ خطة عائلية",
        "ابدا خطة عائلية",
        "انشئ خطة عائلية",
        "جهز خطة عائلية",
        "نظم تجمعا عائليا",
        "ساعدنا نخطط لتجمع عائلي",
        "انشئ تذكيرا",
        "ذكرنا",
        "اطلب تسجيل وصول",
    )
    return _has_classifier_phrase(normalized, action_phrases)


def _classifier_text(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    without_marks = "".join(
        character for character in decomposed if unicodedata.category(character) != "Mn"
    )
    return re.sub(r"\s+", " ", without_marks).strip()


def _has_classifier_phrase(normalized: str, phrases: tuple[str, ...]) -> bool:
    return any(_classifier_text(phrase) in normalized for phrase in phrases)


def _family_subject(normalized: str) -> str | None:
    dad_phrases = (
        "my dad",
        "my father",
        "our dad",
        "our father",
        "where is dad",
        "where's dad",
        "when will dad",
        "what did dad",
        "what is dad doing",
        "what's dad doing",
        "is dad home",
        "is dad late",
        "is dad coming",
        "can dad make",
        "dad shared",
        "dad update",
        "dad's update",
        "dad status",
        "dad's status",
        "dad current status",
        "dad's current status",
        "how is dad doing",
        "أين أبي",
        "اين ابي",
        "أين والدي",
        "اين والدي",
        "أين ابوي",
        "اين ابوي",
        "متى سيصل أبي",
        "متى سيصل ابي",
        "حالة أبي",
        "حالة ابي",
        "تحديث الأب",
    )
    mom_phrases = (
        "my mom",
        "my mother",
        "our mom",
        "our mother",
        "where is mom",
        "where's mom",
        "when will mom",
        "what did mom",
        "what is mom doing",
        "what's mom doing",
        "is mom home",
        "is mom late",
        "is mom coming",
        "can mom make",
        "mom shared",
        "mom update",
        "mom's update",
        "mom status",
        "mom's status",
        "mom current status",
        "mom's current status",
        "how is mom doing",
        "أين أمي",
        "اين امي",
        "أين والدتي",
        "اين والدتي",
        "متى ستصل أمي",
        "متى ستصل امي",
        "حالة أمي",
        "حالة امي",
        "تحديث الأم",
    )
    stripped = normalized.strip(" ?!.,؛؟")
    if stripped in {"dad", "father", "أبي", "ابي", "والدي", "ابوي"} or any(
        phrase in normalized for phrase in dad_phrases
    ):
        return "dad"
    if stripped in {"mom", "mother", "أمي", "امي", "والدتي"} or any(
        phrase in normalized for phrase in mom_phrases
    ):
        return "mom"
    return None


def _format_candidate(value: datetime) -> str:
    hour = value.strftime("%I").lstrip("0") or "0"
    return f"{value.strftime('%A')} at {hour}:{value.strftime('%M %p')}"


app = create_app()
