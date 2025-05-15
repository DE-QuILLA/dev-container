### 사용법
- 먼저
    - GCP 루트가 공유한 SA 키 (key.json)가 이 디렉터리에 존재해야함 **(이름을 바꾼 경우 .gitignore 추가)**
    - GCP 루트가 API를 gcloud services enable 해야함: [compute|container|iam|storage|sql-component].googleapis.com
- 빌드, 런 포함 통합 커맨드 : `./start.sh -i <infra-gitops 프로젝트 경로> -c <code-task 프로젝트 경로> -k <프라이빗 키 경로>`
    - 기본적으로 필수 arg는 없음
    - -i, -c: infra repo, codetask 경로 입력 안하면 디폴트 ./로 입력됨. **깃리포여야 함**
    - -k: ssh 프라이빗키. **.pub 확장자를 빼고** 넣어야 함. ssh, 깃커밋/푸시용 -> -k 넣을 경우 유효성 검사함
    - -h: (한줄짜리)맨페이지
- 이것저것 세팅 후 마지막으로 인터렉티브 bash 세션으로 진입함
- 준비 끗...
- kubectl:
    - 먼저 클러스터 프로비전 후, 
    - `kinit` 사용하면 kube config를 가져옴
    - 현재 클러스터명은 `my-gke` 으로 **하드코딩** 되어잇음 (parameterize 필요)
- helm 차트의 경우 infra-gitops/deploy 에 위치
- vscode 연결
    - vscode 익스텐션에서 `dev container`를 설치
    - ctrl+shift+p (Mac은 cmd+shift+p)에서 `Dev containers: Attach to running containers` 선택
    - /start.sh 로 생성한 dequila-cont 컨테이너 선택
    - 컨테이너를 리모트 dev 환경처럼 쓰는거심니다
- 깃 커밋
    - 커밋 사인을 안 하신다면 여기는 무시하셔도 됩니다
    - **(디폴트)** ssh키를 사용하신다면 `git config --global commit.gpgsign false` 를 해야함
    - gpg키를 사용하신다면
        1. `docker cp <path/to/key.asc> dequila_cont:/root/.gpg/<key.asc>`
        2. 컨테이너 안에서 `gpg --import /root/.gpg/<key.asc>`
        3. `gpg --list-secret-keys --keyid-format=long`으로 조회 후 아이디 해시를
        4. `git config --global user.signingkey <KEY_ID_HASH>` 로 추가
        5. `git config --global commit.gpgsign` 가 true인지 확인. 아니면 true로 설정
        6. 커밋
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