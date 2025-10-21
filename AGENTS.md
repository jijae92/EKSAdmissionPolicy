# Repository Guidelines

## Project Structure & Module Organization
This repository houses Kubernetes admission policies and supporting assets for Amazon EKS clusters. Keep the root limited to documentation and automation configs. Place manifests under `policies/<workload>/base` and environment overlays under `policies/<workload>/overlays/<env>` (for example, `policies/payment-service/overlays/prod`). Reusable charts belong in `templates/`, infrastructure helpers in `infrastructure/`, and regression suites in `tests/`. Document every new top-level directory in `docs/STRUCTURE.md` so future agents can orient quickly.

## Build, Test, and Development Commands
- `kubectl kustomize policies/<workload>/overlays/dev` renders the dev overlay for a fast dry run.
- `kubeconform -summary -strict policies` validates generated manifests against Kubernetes schemas.
- `conftest test policies` runs Rego unit suites to confirm admission logic.
Capture frequently used sequences in `scripts/` or a `Makefile` (for example, `make validate`) and update this list whenever tooling changes.

## Coding Style & Naming Conventions
Use YAML with two-space indentation, alphabetize keys when practical, and anchor shared snippets instead of duplicating blocks. Name policy files after the workload and intent, such as `policies/payment-service/base/mutation.yaml`. Rego packages should follow `package admission.<workload>` naming, with helpers stored under `lib/`. Shell utilities in `scripts/` must pass shellcheck, while Python helpers should be formatted with `black`. Note any deliberate deviations with concise inline comments.

## Testing Guidelines
Mirror every policy bundle with `tests/<workload>` containing `_test.rego` suites and JSON fixtures placed in `tests/<workload>/fixtures/`. Keep fixtures small, anonymized, and representative of real admission requests. Target 100% rule coverage so each deny rule has both positive and negative examples. Run `conftest test` locally before opening a pull request and paste the summarized output when introducing new rules or branches. **All pull requests must pass `gator verify ./tests/gator`; PRs failing gator may not be merged.**

## Commit & Pull Request Guidelines
Adopt Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`) with clear scopes, for example `feat(policies): add pod-level image allowlist`. Reference related GitHub issues or AWS Support cases and include any cluster change window constraints. Pull requests must provide a summary, risk assessment, validation evidence (attach `kubeconform` and `conftest` output), and rollout steps. Request reviews from both infrastructure and security agents when production overlays are affected.
Before requesting review, attach the `gator verify` output and confirm the CI job applying `manifests/bad/` fails with Gatekeeper denials—successful applies are treated as regressions.

## Security & Configuration Tips
Do not commit kubeconfig files, AWS credentials, or other secrets; rely on environment variables and `.env.example` placeholders. Store admission controller certificates in AWS Secrets Manager and record the secret names in `docs/configuration.md`. Verify new policies with `kubectl diff` against a staging cluster before promoting changes to production EKS environments.
Waivers may only be granted via constraint-scoped labels or annotations using `guardrails.gatekeeper.dev/waive-*` keys, and every waiver must include a future expiration date so enforcement resumes automatically.

# 1) Core format — Say it so the model understands in one pass

## 1.1 Pin down Goal · Deliverables · Scope in 3 lines

- **Goal:** One sentence on what to build (or change) and why.
- **Deliverables:** File paths, file count, entry point, output format (console/JSON/file).
- **Scope:** What **not** to do (external DB/schema changes, destructive ops, secret exposure, etc.).

**Example**

```
Goal: Monitor Crossref, PubMed, and RSS by keywords and send a daily digest via SES.
Deliverables: src/watcher.py as entry point, 5 modules under src/*, requirements.txt, .env.example, README.md.
Scope: No external DB creation/schema changes, never hardcode secrets, network timeout 10s.

```

## 1.2 Lock in run/test/deploy commands first

- The model codes better when it knows **how you’ll run it**.
- Provide **local run**, **unit test**, and **container/serverless deploy** commands upfront.

**Example**

```
Run: python -m watcher --once
Test: pytest -q
Docker: docker build -t paper-watcher . && docker run --rm paper-watcher
Serverless: sam build && sam deploy --guided

```

## 1.3 Fix runtime and dependencies

- Specify **runtime versions** (e.g., Python 3.11, Node 20) and **dependency lock** (requirements/lockfile).
- State OS assumptions (Linux/WSL/macOS) and **path style**.

**Example**

```
Runtime: Python 3.11 (Linux/WSL2)
Packages: all in requirements.txt, no extras
Paths: POSIX style (/) enforced; Windows assumes WSL

```

---

# 2) Security & compliance (baseline)

- **Secrets/keys:** Never in code/logs/examples. Use `.env.example` + runtime loading.
- **Network:** 10s timeout + **exponential backoff** with retries for 429/5xx.
- **Logging:** Mask sensitive values; errors include a brief cause + 1–2 lines of context.
- **Least privilege:** File/network/cloud actions limited to what’s necessary.
- **Data handling:** Minimize PII; pseudonymize where possible.
- **Standards (short tags):**
    - Access/privilege: *NIST CSF PR.AC*, *ISO/IEC 27001 A.5.15*
    - Data protection: *NIST CSF PR.DS*, *GDPR Art.32*
    - Logging/audit: *NIST CSF DE.CM*, *ISO/IEC 27001 A.8*

**Single line to include in the prompt**

```
Security: load secrets via .env/secret manager; mask tokens/keys in logs; 10s timeout+backoff; least privilege.

```

---

# 3) Code quality (production habits)

- **Modularization:** Separate entry point (CLI) from pure logic functions.
- **Type hints/Docstrings:** For all public functions/classes.
- **Error handling:** Distinguish usability/env/business errors; friendly messages.
- **Return contract:** CLI uses exit codes (0/1/2…); library raises typed exceptions.
- **Tests:** Core logic covered (≥80%); mock external I/O.
- **Reproducibility:** Provide scripts like `make run/test/build`.

**One-liner to add**

```
Quality: type hints+docstrings, test coverage ≥80%, use CLI exit codes, mock external I/O.

```

---

# 4) File/directory operations (safe even with auto-approve tools)

- Use **explicit paths** only (no mixed relative/absolute confusion).
- For new files: **check existence before create**; for edits: **backup with .bak before modify**.
- Deletes are forbidden by default; if needed, state explicitly (with backup policy).

**One-liner**

```
File policy: check before create, .bak before modify, no deletes unless explicitly requested.

```

---

# 5) Output format, logging, UX

- CLI: **one-line success**; on error, add **root cause + remediation hint** in 1–2 lines.
- `-json` must output **only JSON** (no extra text).
- Provide `-dry-run` and `-verbose` flags by default.

**One-liner**

```
CLI: support --dry-run/--verbose/--json; success is one line; errors include cause + next steps in 1–2 lines.

```

---

# 6) Prompt templates (copy-paste)

## 6.1 “New project” template

```
You are a senior Python engineer and SRE. Produce production-grade code per the spec below.

[Goal]
Collect keyword-matched papers from Crossref/PubMed/RSS once daily and email only new items via Amazon SES.

[Deliverables]
- src/watcher.py (entry: python -m watcher --once)
- src/sources/{crossref.py,pubmed.py,rss.py}
- src/storage.py, src/mailer.py, src/util.py
- tests/test_*.py
- requirements.txt, .env.example, README.md

[Environment]
Python 3.11 (Linux/WSL2). POSIX paths (/). All deps in requirements.txt.

[Run/Deploy]
Run: python -m watcher --once
Test: pytest -q --maxfail=1 --disable-warnings
Docker: docker build -t paper-watcher . && docker run --rm paper-watcher
Serverless: sam build && sam deploy --guided

[Security/Quality]
Load secrets from .env (never hardcode); 10s network timeout + exponential backoff for 429/5xx.
Mask sensitive values in logs. Assume least privilege. Add type hints/docstrings. Test coverage ≥80%.
File policy: check before create, .bak before modify, no deletes.

[Requirements]
- Keyword OR/AND mode, recent N-hour window, de-dup using local SQLite.
- Send email via SES SMTP (STARTTLS). Comma-separated recipients. Prevent header injection.
- CLI options: --once, --dry-run, --window-hours, --keywords, --match-mode, --sources

[Output]
Return only code blocks, each file starting with a header comment line.
Example:
# src/watcher.py
<code>

```

## 6.2 “Modify existing repo” template

```
In the following repo layout, provide COMPLETE updated files (not diffs).
Respect backup policy (.bak). Ensure tests pass.

[Targets]
- Change timeout in src/watcher.py to 10s and use exponential backoff
- Add timeout case to tests/test_watcher.py
- Add tenacity to requirements.txt with pinned version

[Output format]
Each file starts with "# <path>" header. Provide full source only. No extra explanations/links.

```

## 6.3 “Containerize” template

```
Package the project as a container.

[Requirements]
- Base: python:3.11-slim, run as non-root
- Optimize pip cache, pin dependencies
- Add HEALTHCHECK
- Entry: python -m watcher --once

[Deliverables]
- Dockerfile
- docker-compose.yml (optional)
- README section for container run

[Security]
Inject .env at runtime; never bake secrets into image; switch to USER app.

```

## 6.4 “Serverless deployment (SAM)” template

```
Create an AWS SAM template for Lambda+EventBridge+Secrets Manager+SES.

[Requirements]
- template.yaml: function, permissions, daily schedule, env vars, log retention
- src/ handler and requirements.txt
- Reproducible with sam build/deploy
- Default region ap-northeast-2

[Security]
IAM least privilege; read secrets from Secrets Manager; mask sensitive values in logs.

```

## 6.5 “Refactor/perf” template

```
Profile the hot path (HTTP calls/parsing) and reduce p95 latency by 30%.
- Concurrency: only I/O bound with ThreadPoolExecutor
- Cache: 10-min TTL for identical requests
- Logging: INFO summary by default, DEBUG optional

Provide bench.py and a before/after result summary.

```

---

# 7) “Don’t/Watch out” list (avoid common model mistakes)

- **Don’t:** expose secrets/keys/tokens in code/README/logs.
- **Don’t:** cite imaginary APIs/docs or call non-existent modules.
- **Don’t:** mix OS path styles (avoid Windows-style in code).
- **Watch out:** comments inside JSON (breaks parsers).
- **Watch out:** unbounded retries/concurrency.
- **Watch out:** destructive changes without backup (.bak).
- **Watch out:** interface changes without tests.

**One-liner**

```
Forbidden: secret exposure, fake API citations, destructive changes. Beware JSON comments, infinite retries, mixed path styles.

```

---

# 8) One-page “super prompt” (copy-paste)

```
You are a seasoned engineer and SRE. Produce production-grade code under this contract.

[Goal] One sentence.
[Deliverables] File paths/count/entry point/requirements/.env.example/README.
[Environment] Runtime/OS/path rules with versions.
[Run/Test/Deploy] Local, test, Docker, serverless commands must be honored.
[Security] Secrets via .env/secret manager; 10s timeout+backoff; log masking; least privilege.
[Quality] Type hints+docstrings; tests ≥80%; CLI exit codes; mock external I/O.
[File policy] Check before create; .bak before modify; no deletes.
[CLI UX] Support --dry-run/--verbose/--json; one-line success; errors with cause+remedy.
[Requirements] Concrete features (keyword modes, time window, de-dup, etc.).
[Output] Provide COMPLETE files only, each starting with "# <path>". No explanations.
Forbidden/cautions: no secret exposure; no fake citations; no JSON comments; no mixed paths; no overwrite without backup.

```
