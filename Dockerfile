FROM --platform=$TARGETPLATFORM golang:alpine AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

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
    TAG_URL="https://api.github.com/repos/klzgrad/naiveproxy/releases/latest"; \
    VER=$(curl -L "${TAG_URL}" | jq -r '.tag_name'); \
    download_url="https://github.com/klzgrad/naiveproxy/releases/download/${VER}/naiveproxy-${VER}-${architecture}.tar.xz"; \
    curl -L ${download_url} | tar x -Jvf -; \
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
