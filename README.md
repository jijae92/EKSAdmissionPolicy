# EKS Admission Policy — “위험 배포 거부”

Gatekeeper(OPA) 기반의 **쿠버네티스 Admission Policy** 모음과 **실행·검증 도구**를 한 저장소로 묶은 모노레포입니다. 목표는 **취약한 매니페스트의 클러스터 반입 자체를 차단(deny)** 하여 “문제가 생기기 전에 배포를 멈추는” 것입니다.
로컬(kind)부터 Amazon EKS까지 동일한 규칙과 파이프라인으로 적용할 수 있도록 설계되었습니다. 리포 구조는 `policies/`(정책), `manifests/`(데모/검증 리소스), `infra/`(배포 스크립트·템플릿), `docs/`(개요·데모 문서), `tests/`(정책 테스트), `waivers/`(예외)로 구성됩니다.

* 리포지토리: [https://github.com/jijae92/EKSAdmissionPolicy](https://github.com/jijae92/EKSAdmissionPolicy)

---

## 주요 목적 · 문제 정의 · 핵심 기능

* **목적:** 잘못된 K8s 리소스(예: Privileged, HostPath, `:latest` 태그, 퍼블릭 Egress 등)를 **사전에 거부**합니다.
* **문제 정의:** 런타임에서 탐지·대응하면 이미 위험이 노출됩니다. Admission 시점에서 정책을 통과한 오브젝트만 클러스터에 들어오게 해야 합니다.
* **핵심 기능:**

  * Gatekeeper `ConstraintTemplate`/`Constraint` 기반 **정책 집합** (`policies/`)
  * 로컬(kind) 및 Amazon EKS로 **동일 정책 적용**
  * **Waiver(예외) 정책:** 사유·만료 시점 없는 무기한 예외 금지, **만료 기반 자동 복구**
  * CI에서 정책 스캔·차단, 수동 승인과 배포 단계 연계(파이프라인 예시)

---

## 데모 스크린샷 / 링크

* `docs/`의 개요·데모 문서 참고: `docs/README.md`, `docs/DEMO.md`
* 리포 루트 README(개요/웨이버 정책 요약): [https://github.com/jijae92/EKSAdmissionPolicy/blob/main/README.md](https://github.com/jijae92/EKSAdmissionPolicy/blob/main/README.md)

---

## 빠른 시작(Quick Start)

> **사전 요구:** `kubectl`, `helm`, `kind` 또는 EKS 컨텍스트, `make` (AWS 사용 시 `aws` CLI와 자격 구성)

### 1) 로컬(kind) 체험

```bash
# 1) kind 클러스터 생성
kind create cluster --name ap-guardrails

# 2) Gatekeeper 설치
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace

# 3) 정책 배포(ConstraintTemplate → Constraint)
kubectl apply -f policies/templates/        # ConstraintTemplate들
kubectl apply -f policies/constraints/      # 실제 차단 규칙

# 4) 데모 매니페스트 적용(의도적으로 취약)
kubectl apply -f manifests/vulnerable/ || true

# 5) 기대 결과: Admission webhook이 "deny"로 거부
```

### 2) Amazon EKS 적용(선택)

```bash
# 1) 컨텍스트 전환
aws eks update-kubeconfig --name <EKS_CLUSTER> --region <ap-northeast-2>

# 2) Gatekeeper 배포(Helm 또는 infra 스크립트)
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace

# 3) 동일 정책/데모 적용
kubectl apply -f policies/templates/
kubectl apply -f policies/constraints/
kubectl apply -f manifests/vulnerable/ || true
```

### 3) 정책 통과 확인

```bash
kubectl apply -f manifests/safe/
kubectl get constraints --all-namespaces
kubectl get constrainttemplates
kubectl get events -A | grep -i webhook
```

---

## 설정 · 구성

* **정책(필수):**

  * `policies/templates/` — `ConstraintTemplate`(Rego 동작 정의)
  * `policies/constraints/` — `Constraint`(클러스터 적용 규칙)
  * 기본 Enforcement는 **deny** 권장.
* **웨이버(예외):**

  * 네임스페이스 단위: `guardrails.gatekeeper.dev/waive=true` 라벨 + **만료 주석** 필수
  * 오브젝트 단위: `guardrails.gatekeeper.dev/waive-reason`, `guardrails.gatekeeper.dev/waive-until` **반드시** 포함
  * 만료 시 자동 복원(deny)로 되돌아가도록 운영
* **인프라:**

  * `infra/`에 EKS 배포 스크립트/템플릿(컨텍스트, 네임스페이스, Helm 값 등)
* **데모/검증 리소스:**

  * `manifests/`에 취약/정상 예시가 분리되어 학습·CI 재현에 사용
* **자동화:**

  * `Makefile`에 공통 명령(예: `make bootstrap`, `make apply-policies`, `make demo`, `make cleanup`)

---

## 아키텍처 개요

* **Gatekeeper(OPA):** Admission Webhook으로 동작하며 템플릿/제약을 통해 정책을 집행
* **Policies:** `ConstraintTemplate`(행동 정의) + `Constraint`(적용 범위·파라미터)
* **Waiver 흐름:** 라벨·어노테이션로 “언제/왜” 예외인지 추적, **만료일** 기반 자동 복구
* **CI/CD(예시):** PR → 정책 스캔 → 실패 시 차단 → 수동 승인 → 배포

---

## 운영 방법

* **로그 위치**

  * Gatekeeper 컨트롤러/웹훅:
    `kubectl -n gatekeeper-system logs deploy/gatekeeper-controller-manager -f`
  * 거부/허용 이벤트:
    `kubectl get events -A | grep -i webhook`
* **헬스체크**

  * `kubectl -n gatekeeper-system get pods`
  * `kubectl get constrainttemplates, constraints -A`
* **모니터링**

  * `kubectl top` 및 컨트롤러 메트릭(선택: Prometheus/Alertmanager 연계)
* **자주 나는 장애 · 복구 절차**

  * 증상: 정상 매니페스트도 거부 → 조치: 최근 추가된 Constraint `kubectl describe` 확인, 임시 `enforcementAction: dryrun` 전환 후 원인 분석
  * 증상: 웹훅 타임아웃 → 조치: Gatekeeper Pod 상태/리소스 확인, `--webhook-timeout-seconds` 조정, 롤아웃 재시작
  * 증상: 무기한 예외 잔존 → 조치: 네임스페이스 라벨·만료 주석·`waivers/` 점검, 만료일 경과 시 제거

---

## 보안 · 컴플라이언스

* **비밀 관리:** 자격/토큰을 커밋하지 말고 Kubernetes Secret 또는 AWS Secrets Manager 사용
* **최소 권한(IAM):** 파이프라인이 `kubectl`을 쓸 경우 필요한 리소스에만 권한 할당
* **로그/감사:** 정책 로그·이벤트를 중앙화(CloudWatch/ELK 등)하고 조직 보존 기간(예: 90/180일) 준수
* **취약점 신고:** `SECURITY.md` 또는 보안 채널을 통해 제보(일반 이슈 트래커 사용 지양)

---

## 기여 가이드

* **브랜치 전략:** `main` 보호, 기능은 `feat/*`, 수정은 `fix/*` 브랜치에서 PR
* **코드 스타일:** YAML 2스페이스, 라벨/어노테이션 키 접두 `guardrails.gatekeeper.dev/*` 유지
* **커밋 규칙:** Conventional Commits(`feat:`, `fix:`, `docs:`…)
* **PR 템플릿:** 변경 이유, 영향 객체, 테스트/검증 방법, 롤백 전략 포함
* **테스트 기준:** `tests/`에 정책 단위 테스트(가능 시 gator/OPA 테스트 툴)

---

## 라이선스 / 저작권

* `<LICENSE>`에 라이선스 명시(예: Apache-2.0). 외부 정책/샘플 출처·저작권 표기.

---

## 변경 이력(Release Notes)

* `CHANGELOG.md` 또는 GitHub Releases를 사용해 버전 이력 관리
* 첫 배포 시 `v0.1.0`부터 시작 권장

---

## 실무 팁(보안/SRE)

* README에 **비밀값 금지**: 샘플은 `values.example.yaml` 또는 Secret 템플릿으로 제공
* 환경별 차이 명확화: `NamespaceSelector`, `enforcementAction`를 dev/stage/prod로 분리
* 장애 시 1줄 복구: “웹훅 타임아웃 → 컨트롤러 로그 확인 → 최신 Constraint dry-run 전환 → 원인 분석 후 재적용”
* 자동화 명령 통일: `make bootstrap`, `make apply-policies`, `make demo`, `make cleanup`
* 문서 분리: 상세 런북/보안정책은 위키/런북으로, README는 **입구/개요** 역할

---

## 부록: 유용한 커맨드

```bash
# 정책 배포/삭제
kubectl apply -f policies/templates/ && kubectl apply -f policies/constraints/
kubectl delete -f policies/constraints/ && kubectl delete -f policies/templates/

# Gatekeeper 상태
kubectl -n gatekeeper-system get pods
kubectl get constrainttemplates
kubectl get constraints --all-namespaces

# 특정 Constraint 디버깅
kubectl describe constraint <KIND>.<NAME>
kubectl get events -A | grep -i gatekeeper
```

---

### 링크

* 리포지토리: [https://github.com/jijae92/EKSAdmissionPolicy](https://github.com/jijae92/EKSAdmissionPolicy)
* `infra/`(EKS 스크립트·템플릿): [https://github.com/jijae92/EKSAdmissionPolicy/tree/main/infra](https://github.com/jijae92/EKSAdmissionPolicy/tree/main/infra)
* `manifests/`(취약/정상 샘플): [https://github.com/jijae92/EKSAdmissionPolicy/tree/main/manifests](https://github.com/jijae92/EKSAdmissionPolicy/tree/main/manifests)
