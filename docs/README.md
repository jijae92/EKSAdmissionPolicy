## 프로젝트 목적
- **위험 배포 사전 차단:** Gatekeeper 기반 사전 검증으로 특권 컨테이너, 허술한 네임스페이스, latest 이미지 등 고위험 패턴을 차단합니다.
- **정책 일관성 유지:** Amazon EKS와 개발용 kind 모두에서 동일한 정책 템플릿을 적용해 환경 간 편차를 줄입니다.
- **예외 관리 체계화:** 예외는 반드시 사유와 만료일을 포함해 감사 가능성을 확보합니다.

## 정책 목록 (핵심 8종)
1. **PSPPrivilegedDeny** – `securityContext.privileged=true` 컨테이너 금지
2. **PSPHostNamespacesDeny** – `hostPID`, `hostIPC`, `hostNetwork`, `hostPath` 사용 차단
3. **PSPCapabilities** – `drop: ["ALL"]` 요구 및 `add` 최소 허용(기본: `NET_BIND_SERVICE`)
4. **PSPRunAsNonRoot** – `runAsNonRoot=true` 또는 비루트 `runAsUser` 강제
5. **PSPSeccompDefault** – `seccompProfile.type`을 `RuntimeDefault`/`Localhost`로 제한
6. **ImageRegistryAllowlist** – 허용 레지스트리(예: 조직 ECR, `gcr.io/your-org`)만 사용
7. **ImageNoLatestTag** – `:latest`·태그 미지정 이미지 금지, digest 또는 고정 태그 요구
8. **RequireRequestsLimits** – 모든 컨테이너에 CPU/메모리 요청·제한 필수

*보너스 정책:* `DenyNodePort`, `IngressTLSHost`는 필요 시 선택적으로 적용 가능합니다.

### 예외(웨이버) 원칙
- `guardrails.gatekeeper.dev/waive-reason`: 예외 사유(사람이 읽을 수 있어야 함)
- `guardrails.gatekeeper.dev/waive-until`: ISO 날짜(예: `2025-12-31`) 또는 RFC3339 만료 시점
- 만료일이 경과하면 자동으로 차단이 재개되므로 주기적으로 재평가합니다.

## 빠른 시작
1. **클러스터 생성**
   ```bash
   make kind
   ```
2. **Gatekeeper + 정책 배포**
   ```bash
   make up
   ```
3. **위반 시나리오 확인 (`manifests/bad/`)**
   ```bash
   ./scripts/test_violation_demo.sh
   # 또는 kubectl apply -f manifests/bad/
   ```
4. **준수 시나리오 확인 (`manifests/good/`)**
   ```bash
   kubectl apply -f manifests/good/
   ```
5. **정리**
   ```bash
   make clean
   make down
   ```

## 운영 팁
- **단계적 enforcement:** 새로운 규칙은 `enforcementAction: dryrun`으로 배포해 영향 범위를 파악한 뒤 `deny`로 전환합니다.
- **네임스페이스별 롤아웃:** 파일럿 네임스페이스부터 적용하고, 업무 라인별로 라벨·어노테이션을 활용해 점진적으로 확대합니다.
- **웨이버 관리:** 예외 적용 내역은 Git PR로 기록하고 만료일이 가까워지면 사전 알림(Automation/SRE)으로 재검토합니다.

## Mutation 예시 (Assign/AssignMetadata)
- **seccompProfile 자동 주입**
  ```yaml
  # policies/mutations/assign-seccomp-default.yaml
  apiVersion: mutations.gatekeeper.sh/v1
  kind: Assign
  metadata:
    name: assign-seccomp-runtime-default
  spec:
    location: spec.template.spec.securityContext.seccompProfile.type
    parameters:
      assign:
        value: RuntimeDefault
  ```
- **imagePullPolicy IfNotPresent 강제**
  ```yaml
  # policies/mutations/assign-imagepullpolicy.yaml
  apiVersion: mutations.gatekeeper.sh/v1
  kind: Assign
  metadata:
    name: assign-imagepullpolicy-ifnotpresent
  spec:
    location: spec.containers[name:*].imagePullPolicy
    parameters:
      assign:
        value: IfNotPresent
  ```
> StatefulSet/Deployment 등 템플릿 오브젝트에 적용하려면 `applyTo`/`location`을 `spec.template.spec.containers[name:*].imagePullPolicy`로 조정한 별도 Assign 리소스를 추가하세요.

## GitOps (Argo CD / Flux) 연계 샘플
- **Argo CD Application**
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: gatekeeper-policies
    namespace: argocd
  spec:
    destination:
      namespace: gatekeeper-system
      server: https://kubernetes.default.svc
    project: default
    source:
      repoURL: https://github.com/your-org/EKSAdmissionPolicy.git
      targetRevision: main
      path: policies
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
      syncOptions:
        - CreateNamespace=false
  ```
- **Flux Kustomization**
  ```yaml
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: gatekeeper-policies
    namespace: flux-system
  spec:
    interval: 5m
    prune: true
    sourceRef:
      kind: GitRepository
      name: eks-admission-policy
    path: "./policies"
    timeout: 2m
  ```
> Git 저장소 변경이 자동으로 Gatekeeper에 동기화되므로 릴리즈 노트와 CI 파이프라인을 연계해 배포 이력을 추적하세요.

## 컴플라이언스 매핑
- **NIST SP 800-53**  
  - AC-6: 최소 권한 → Privileged 차단, Capability 제한  
  - SC-7: 경계 보호 → Host 네임스페이스 및 NodePort 제한
- **ISO/IEC 27001**  
  - Annex A.9 (Access Control): 비루트 실행, 이미지 통제 정책
- **AWS Well-Architected – Security Pillar**  
  - SEC05(자동화된 보안 베스트프랙티스), SEC09(워크로드 보호)에 기여

## 보안 정책 업데이트
- 릴리즈 노트: [GitHub Releases](https://github.com/your-org/EKSAdmissionPolicy/releases)에서 정책 변경·테스트 결과를 문서화합니다.
- 새 정책 추가 시 `policies/`, `tests/gator/`, `manifests/` 및 본 문서를 반드시 업데이트합니다.

## Amazon EKS 배포 가이드
1. **클러스터 프로비저닝**
   ```bash
   eksctl create cluster -f infra/eks/eksctl-config.yaml
   ```
2. **Gatekeeper 설치**
   ```bash
   ./infra/eks/install_gatekeeper.sh
   ```
3. **정책 적용**
   ```bash
   ./scripts/apply_policies.sh
   ```
> 스크립트 실행 후 `kubectl get pods -n gatekeeper-system`으로 상태를 확인하고, 필요 시 GitOps 연계를 통해 정책을 지속적으로 동기화하세요.
