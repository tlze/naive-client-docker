FROM --platform=$TARGETPLATFORM golang:alpine AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN apk add --no-cache curl jq

WORKDIR /go
RUN set -eux; \
    \
    case ${TARGETPLATFORM} in \
        "linux/amd64")  architecture=linux-x64 ;; \
        "linux/arm64")  architecture=linux-arm64 ;; \
    esac; \
    \
    TAG_URL="https://api.github.com/repos/klzgrad/naiveproxy/releases/latest"; \
    VER=$(curl -L "${TAG_URL}" | jq -r '.tag_name'); \
    download_url="https://github.com/klzgrad/naiveproxy/releases/download/${VER}/naiveproxy-${VER}-${architecture}.tar.xz"; \
    curl -L ${download_url} | tar x -Jvf -; \
    mv naiveproxy-* naiveproxy;

FROM --platform=$TARGETPLATFORM debian:bookworm-slim AS runtime
ARG TARGETPLATFORM
ARG BUILDPLATFORM

COPY --from=builder /go/naiveproxy/naive /usr/local/bin/
COPY --from=builder /go/naiveproxy/config.json /etc/naiveproxy/config.json

RUN set -eux; \
    runDeps=" \
        ca-certificates \
        libstdc++6 \
    "; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        $runDeps \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    chmod +x /usr/local/bin/*;

CMD ["/usr/local/bin/naive", "/etc/naiveproxy/config.json" ]
