default:
    @just --list

# 提交全部改动并推送，触发云端构建（本地零构建）
push *msg:
    @git add -A && git -c user.name="hnzxb" -c user.email="hnzxb@users.noreply.github.com" commit -m "{{msg}}" || true
    @GIT_SSH_COMMAND="ssh -p 443 -o ProxyCommand=none" git push origin main

# 等待最新一次 Personal build 结束并打印结论
watch:
    @RUN=$(gh run list --repo hnzxb/misc.cmux --workflow personal-build.yml --limit 1 --json databaseId --jq '.[0].databaseId') && \
    echo "watching run $$RUN" && \
    gh run watch $$RUN --repo hnzxb/misc.cmux --exit-status --interval 60

# 下载最新成功构建的产物到 /tmp/cmux-artifact/ 并解压
download:
    @rm -rf /tmp/cmux-artifact && mkdir -p /tmp/cmux-artifact && \
    RUN=$$(gh run list --repo hnzxb/misc.cmux --workflow personal-build.yml --status success --limit 1 --json databaseId --jq '.[0].databaseId') && \
    echo "downloading from run $$RUN" && \
    gh run download $$RUN --repo hnzxb/misc.cmux --name cmux-debug-ci-fix --dir /tmp/cmux-artifact && \
    unzip -q /tmp/cmux-artifact/cmux-ci-fix.zip -d /tmp/cmux-artifact/unz && \
    ls /tmp/cmux-artifact/unz

# 替换 /Applications/cmux.app（旧版归档到 archive/，需用户确认 cmux 可重启）
install:
    @bash scripts/replace-cmux.sh

# 一条龙：推送 → 等构建 → 下载 → 替换并重启
ship *msg:
    @just push {{msg}}
    @just watch
    @just download
    @just install
