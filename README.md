### 사용법
- 빌드, 런 포함 통합 커맨드 : `./start.sh -i <infra-gitops 프로젝트 경로> -c <code-task 프로젝트 경로> -m <helm 프로젝트 경로> -k <프라이빗 키 경로>`
    - infra repo, codetask, helm 경로 입력 안하면 디폴트 ./로 입력됨.
    - infra, codetask는 깃리포여야 함.
    - 프라이빗키: .pub 확장자를 빼고 넣어야합니다~ ssh, 깃커밋/푸시용 -> 넣을 경우 유효성 검사 체크함.
- 이것저것 세팅 후 마지막으로 인터렉티브 bash 세션으로 진입함
- 준비 끗...
- kubectl:
    - 먼저 클러스터 프로비전 후, 
    - `kinit` 사용하면 kube config를 가져옴
    - 현재 `my-gke`, `my-code-vocab`으로 하드코딩 되어잇음 (클러스터 명, G프로젝트명 parameterize 필요)
- vscode 연결
    - vscode 익스텐션에서 `dev container`를 설치
    - ctrl+shift+p (Mac은 cmd+shift+p)에서 `Dev containers: Attach to running containers` 선택
    - /start.sh 로 생성한 dequila-cont 컨테이너 선택
    - 컨테이너를 리모트 dev 환경처럼 쓰는거심니다
- 그만하기... 
    - 컨테이너를 켜둔 상태로 ./start 하면 컨테이너를 지우고 다시 시작함니다
    - 멈출 때는 `./stop.sh`
- [노션문서](https://www.notion.so/gke-1d290ab6365f808ab786eafd6bf57a63)
    - 노션의 gke 접근 문서 참조
    - key.json은 빌드타임에 컨테이너 안에 들어감

### TODOs
- [x] install script
- [x] start script / inclusive with install script
- [ ] 클러스터 이름, (GCP)프로젝트 이름 픽스 필요
- [ ] 서비스 키: 계정 바뀔때 대비 parameterize
- [x] argument 핸들링