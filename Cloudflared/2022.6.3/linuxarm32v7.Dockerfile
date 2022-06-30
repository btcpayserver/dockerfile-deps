# use a builder image for building cloudflare
ARG TARGET_GOOS=linux
ARG TARGET_GOARCH=arm
ARG TARGET_PLATFORM=arm
ARG CLOUDFLARED_VERSION=2022.6.3
FROM golang:1.17.1 as builder
ARG CLOUDFLARED_VERSION
ARG TARGET_GOARCH
ARG TARGET_GOOS
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    TARGET_OS=${TARGET_GOOS} \
    TARGET_ARCH=${TARGET_GOARCH}
LABEL org.opencontainers.image.source="https://github.com/cloudflare/cloudflared"

WORKDIR /go/src/github.com/cloudflare/cloudflared/

RUN git clone --branch ${CLOUDFLARED_VERSION} --single-branch --depth 1 https://github.com/cloudflare/cloudflared.git .

# compile cloudflared
RUN make cloudflared

# use a distroless base image with glibc
FROM --platform=${TARGET_PLATFORM} gcr.io/distroless/base-debian10:nonroot

# copy our compiled binary
COPY --from=builder --chown=nonroot /go/src/github.com/cloudflare/cloudflared/cloudflared /usr/local/bin/

# run as non-privileged user
USER nonroot

# command / entrypoint of container
ENTRYPOINT ["cloudflared", "--no-autoupdate"]
CMD ["version"]