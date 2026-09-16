# AppGym

Personal, local, offline gym-tracking iPhone app. MVP v0.1. See `README.md`
for the repo layout, `docs/ARCHITECTURE.md` for the domain model and
invariants, `docs/DEVELOPMENT.md` for build/test/run commands, and
`docs/PRODUCT_DECISIONS.md` for calls made where the product spec was
ambiguous.

Start with `docs/ARCHITECTURE.md` before touching `AppGymKit` — it explains
which invariants exist and why, so a change doesn't accidentally reopen one
(e.g. history mutating when a template changes, or a second active session
becoming possible).
