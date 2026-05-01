FROM --platform=$TARGETPLATFORM golang:alpine AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG GITHUB_TOKEN

# RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN apk add --no-cache curl jq

WORKDIR /go
RUN set -eux; \
    \
    case ${TARGETPLATFORM} in \
        "linux/amd64")  architecture=openwrt-x86_64  ;; \
        "linux/arm64")  architecture=openwrt-aarch64_generic ;; \
        "linux/arm/v7") architecture=openwrt-arm_cortex-a15_neon-vfpv4 ;; \
    esac; \
    \
    if [ -n "$GITHUB_TOKEN" ]; then \
        auth_header="-H Authorization: Bearer $GITHUB_TOKEN"; \
    else \
        auth_header=""; \
    fi; \
    download_url=$(curl -L $auth_header https://api.github.com/repos/klzgrad/naiveproxy/releases/latest | jq -r --arg assert "^naiveproxy-.+$architecture" '.assets[] | select (.name | test($assert))| .browser_download_url' -); \
    curl -L $download_url | tar x -Jvf -; \
    mv naiveproxy-* naiveproxy;

FROM --platform=$TARGETPLATFORM alpine:latest AS runtime
ARG TARGETPLATFORM
ARG BUILDPLATFORM

COPY --from=builder /go/naiveproxy/naive /usr/local/bin/
COPY --from=builder /go/naiveproxy/config.json /etc/naiveproxy/config.json

RUN set -eux; \
    \
    runDeps=" \
        ca-certificates \
        libstdc++ \
    "; \
    \
    apk add --virtual .run-deps \
        $runDeps \
    ; \
    \
    chmod +x /usr/local/bin/*;


CMD ["naive", "/etc/naiveproxy/config.json" ]
