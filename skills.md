You are continuing development of an existing project called EventFlow.

Before doing anything else, read these two files fully and keep them as your
persistent mental model for the entire session:

1. SRS.txt — the complete Software Requirements Specification (functional
   requirements FR-xxx, non-functional requirements NFR-xxx, architecture,
   data model, agent tool schemas, use cases).
2. SKILLS.md — the current project state, tech stack, conventions, and
   build-order map. Treat this as your source of truth for "what already
   exists vs what is missing."

Context:
EventFlow already has a partially built Flutter app (GitHub repo:
MalaikaAltaf/eventflow) with Firebase Auth + Firestore, Riverpod, GoRouter,
and easy_localization already wired up. The customer event-setup wizard UI,
vendor onboarding/inbox/profile UI, and a partial vendor-side Firestore
negotiation write path already exist. There is currently NO Python backend,
NO real AI agent logic (the live negotiation dashboard uses a fake random
number generator that must be removed), and NO customer profile/history
screens.

Your task:
Do NOT rebuild the project from scratch. Clone/open the existing repository,
respect its existing folder structure, naming conventions, theme, and state
management patterns, and build ONLY what is missing or fake, exactly as
specified in SRS.txt. Specifically:

1. Build a new Python (FastAPI) backend service implementing the Analyzer
   Agent, per-vendor Negotiation Agents (running in parallel), and the
   Aggregator Agent, each calling the Fireworks AI OpenAI-compatible chat
   completions API (https://api.fireworks.ai/inference/v1) with the tool
   schemas defined in SRS.txt Appendix A. Never call Fireworks AI from the
   Flutter client — all LLM calls go through this backend.
2. Wire the existing negotiation_service.dart write path to a real backend
   webhook so a vendor's manual reply re-invokes that vendor's Negotiation
   Agent (per FR-VND-03 / FR-NEG in SRS.txt).
3. Replace the fake Random()-based simulator in live_dashboard_screen.dart
   with real Firestore listeners reading agent/vendor messages written by
   the backend.
4. Add the missing customer profile and event-history screens (FR-CPR-01 to
   FR-CPR-04) — there is currently no customer-side equivalent of the
   existing vendor profile/bookings screens.
5. Add the PostgreSQL schema and models described in SRS.txt Section 6.1
   for transactional data (users, events, allocations, vendors,
   negotiations, bookings, llm_usage_log), separate from the Firestore
   realtime layer.
6. Implement vendor matching, budget aggregation, and booking confirmation
   endpoints per Sections 3.4, 3.7, and 3.8 of SRS.txt.
7. Apply the non-functional requirements as you build — especially
   NFR-SEC-02 (secrets never in client), NFR-REL-02 (idempotent negotiation
   rounds), and NFR-PERF-02 (true parallel negotiation, not sequential).

Work in the phased order given in SKILLS.md ("Build Order"), one phase at a
time. After each phase, tell me what you built, what SRS requirement IDs it
satisfies, and what's still missing before moving to the next phase. Ask me
before making any architectural decision that SRS.txt leaves ambiguous.
