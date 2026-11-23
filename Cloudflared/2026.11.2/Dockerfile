FROM --platform=$BUILDPLATFORM golang:1.27.4 AS builder

ARG TARGETOS
ARG TARGETARCH
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOPROXY=https://proxy.golang.org|direct \
    TARGET_GOOS=${TARGETOS} \
    TARGET_GOARCH=${TARGETARCH} \
    CONTAINER_BUILD=1 \
    CLOUDFLARED_VERSION=2026.11.2
WORKDIR /go/src/github.com/cloudflare/cloudflared/

# copy our sources into the builder image
RUN git clone --branch ${CLOUDFLARED_VERSION} --single-branch --depth 1 https://github.com/cloudflare/cloudflared.git .

# Download dependencies separately from compilation.
RUN go mod download

# compile cloudflared
RUN GOOS=${TARGET_GOOS} GOARCH=${TARGET_GOARCH} make cloudflared

# use a distroless base image with glibc
FROM gcr.io/distroless/base-debian13:nonroot@sha256:83e67481ae9fc8c7a6d211113431fb8085619bed49672e583261111bac184f0d

LABEL org.opencontainers.image.source="https://github.com/cloudflare/cloudflared"

# copy our compiled binary
COPY --from=builder --chown=nonroot /go/src/github.com/cloudflare/cloudflared/cloudflared /usr/local/bin/

# run as nonroot user
USER 65532:65532

# Keep autoupdate disabled even when the entrypoint is overridden.
ENV NO_AUTOUPDATE=true

# command / entrypoint of container
ENTRYPOINT ["cloudflared"]
CMD ["version"]
