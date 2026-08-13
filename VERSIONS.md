# Family Compass versions

This repository keeps completed prototypes as fixed historical snapshots and develops the current mobile application separately.

| Product stage | Version | Status | Source | Git reference |
|---|---:|---|---|---|
| Prototype 1 | `0.1.0+1` | Frozen exploration | `prototypes/prototype-1` | `prototype-1-v0.1.0` |
| Prototype 2 | `0.2.0+2` | Frozen experience prototype | `prototypes/prototype-2` | `prototype-2-v0.2.0` |
| Version 1 application foundation | `0.3.0-dev.1+3` | Active pre-release | `apps/family_compass` | Not released |
| Prototype 3 backend foundation | `0.3.0-dev.1`, schema `4` | Active pre-release | `family_compass_backend` | Not released |
| Version 1 production release | `1.0.0` | Gated | Active app and backend after release checks | Not created |

## Repository layout

- `prototypes/prototype-1` and `prototypes/prototype-2` are preserved for comparison. Their version files and immutable tags define their final state.
- `apps/family_compass` is the only active Flutter application.
- `family_compass_backend` is the FastAPI service paired with the active application.
- `PRODUCT.md`, `DESIGN.md`, and `TODO.md` define the product, interface, and remaining work across versions.
- `docs` contains research, setup guides, validation records, and release gates. Final screenshots for the active foundation are under `docs/assets/version-1-foundation`.

## Version rules

1. Do not modify a frozen prototype for new features. Apply only a documented build-recovery or security repair.
2. Keep the Flutter package version, its `VERSION.md`, and this file synchronized.
3. Record backend schema and compatibility changes in `family_compass_backend/VERSION.md`.
4. Use pre-release versions until the production gates in `docs/PRODUCT_ROADMAP.md` and `TODO.md` pass.
5. Create an immutable annotated tag only for a deliberate release snapshot. The active foundation remains untagged until its next release decision.
