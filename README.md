### 사용법
- 커맨드 사용하고 컨테이너 버릴 경우
    - `docker run --rm [image_name] [command]`
- 컨테이너 안의 셸에서 작업할 경우
    - `docker run -it --rm [image_name]`
- [command]
    - 노션의 gke 접근 문서 참조
    - key.json은 빌드타임에 컨테이너 안에 들어감

### TODOs
- [ ] install script
    - add start script to alias in the user's shell
    - so it can be used from other directories
    - and then check for image name existence -> build image
- [ ] start script
    - always --rm
    - additional argument passed -> docker run,
    - if not -> docker run -it