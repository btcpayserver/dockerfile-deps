FROM --platform=$BUILDPLATFORM golang:1.26.8 AS builder

ARG TARGETOS
ARG TARGETARCH
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOPROXY=https://proxy.golang.org|direct \
    TARGET_GOOS=${TARGETOS} \
    TARGET_GOARCH=${TARGETARCH} \
    CONTAINER_BUILD=1 \
    CLOUDFLARED_VERSION=2026.9.1
WORKDIR /go/src/github.com/cloudflare/cloudflared/

# copy our sources into the builder image
RUN git clone --branch ${CLOUDFLARED_VERSION} --single-branch --depth 1 https://github.com/cloudflare/cloudflared.git .

# Download dependencies separately from compilation.
RUN go mod download

# compile cloudflared
RUN GOOS=${TARGET_GOOS} GOARCH=${TARGET_GOARCH} make cloudflared

# use a distroless base image with glibc
FROM gcr.io/distroless/base-debian13:nonroot@sha256:d199d20fb09c898d8822ae5cbd5cf3c6d424e9b5e1fc2eb9a719a7752cd9d861

LABEL org.opencontainers.image.source="https://github.com/cloudflare/cloudflared"

# copy our compiled binary
COPY --from=builder --chown=nonroot /go/src/github.com/cloudflare/cloudflared/cloudflared /usr/local/bin/

# run as nonroot user
USER 65532:65532

# command / entrypoint of container
ENTRYPOINT ["cloudflared", "--no-autoupdate"]
CMD ["version"]
