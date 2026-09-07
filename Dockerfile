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
        api_json=$(curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/repos/klzgrad/naiveproxy/releases/latest); \
    else \
        api_json=$(curl -sSL https://api.github.com/repos/klzgrad/naiveproxy/releases/latest); \
    fi; \
    download_url=$(printf '%s' "$api_json" | jq -r --arg assert "^naiveproxy-.+$architecture\\.tar\\.xz$" '.assets[] | select (.name | test($assert)) | .browser_download_url' | grep -v -- '-static\.tar\.xz$' | head -n 1); \
    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then echo "failed to resolve download url for $architecture"; printf '%s' "$api_json" | head -c 1000; echo; exit 1; fi; \
    curl -fsSL "$download_url" | tar x -Jvf -; \
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
