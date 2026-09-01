FROM --platform=$BUILDPLATFORM golang:1.26.4 AS builder

ARG TARGETARCH
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    CONTAINER_BUILD=1 \
    CLOUDFLARED_VERSION=2026.8.3
WORKDIR /go/src/github.com/cloudflare/cloudflared/

# copy our sources into the builder image
RUN git clone --branch ${CLOUDFLARED_VERSION} --single-branch --depth 1 https://github.com/cloudflare/cloudflared.git .

# compile cloudflared
RUN GOOS=linux GOARCH=${TARGETARCH} make cloudflared

# use a distroless base image with glibc
FROM gcr.io/distroless/base-debian13:nonroot@sha256:97b9d04bed1c754b756c3c4b6a04915c22fb0b5d96a59944eb3bf78c26e6e157

LABEL org.opencontainers.image.source="https://github.com/cloudflare/cloudflared"

# copy our compiled binary
COPY --from=builder --chown=nonroot /go/src/github.com/cloudflare/cloudflared/cloudflared /usr/local/bin/

# run as non-privileged user
USER 65532:65532

# command / entrypoint of container
ENTRYPOINT ["cloudflared", "--no-autoupdate"]
CMD ["version"]
