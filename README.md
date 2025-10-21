# EKS Admission Policy Monorepo

This repository bootstraps a Gatekeeper-based admission control stack for local kind clusters and optional Amazon EKS deployments. Start with `docs/README.md` for an overview, `docs/DEMO.md` for hands-on steps, and consult `AGENTS.md` for contributor guidelines.

## Waiver Policy

- Default all constraints to `enforcementAction: deny`; opt-out namespaces must be labeled separately or patched out.
- Temporary exceptions must include `guardrails.gatekeeper.dev/waive-reason` and `guardrails.gatekeeper.dev/waive-until` annotations so reviewers can trace an owner and expiry date.
- Use namespace label `guardrails.gatekeeper.dev/waive=true` for wholesale namespace waivers and set an expiration annotation to document the review window.
- Object-level waivers expire automatically once `guardrails.gatekeeper.dev/waive-until` is in the past, restoring enforcement without manual cleanup.
