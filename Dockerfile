# Build image
FROM golang:1.23-alpine3.21 AS builder

ENV GOFLAGS="-mod=readonly"

RUN apk add --update --no-cache ca-certificates make git curl mercurial

RUN mkdir -p /workspace
WORKDIR /workspace

ARG GOPROXY

COPY go.* /workspace/
RUN go mod download

COPY Makefile main-targets.mk /workspace/

COPY . /workspace

ARG BUILD_TARGET

RUN set -xe && \
    if [[ "${BUILD_TARGET}" == "debug" ]]; then \
        cd /tmp; GOBIN=/workspace/build/debug go get github.com/go-delve/delve/cmd/dlv; cd -; \
        make build-debug; \
        mv build/debug /build; \
    else \
        make build-release; \
        mv build/release /build; \
    fi


# Final image
FROM alpine:edge

RUN apk add --update --no-cache ca-certificates tzdata bash curl libcrypto3 libssl3

SHELL ["/bin/bash", "-c"]

# set up nsswitch.conf for Go's "netgo" implementation
# https://github.com/gliderlabs/docker-alpine/issues/367#issuecomment-424546457
RUN echo 'hosts: files dns' > /etc/nsswitch.conf
#RUN test ! -e /etc/nsswitch.conf && echo 'hosts: files dns' > /etc/nsswitch.conf

ARG BUILD_TARGET

RUN if [[ "${BUILD_TARGET}" == "debug" ]]; then apk add --update --no-cache libc6-compat; fi

COPY --from=builder /build/* /usr/local/bin/

COPY configs /etc/cloudinfo/serviceconfig

RUN sed -i "s|dataLocation: ./configs/|dataLocation: /etc/cloudinfo/serviceconfig/|g" /etc/cloudinfo/serviceconfig/services.yaml

ENV CLOUDINFO_SERVICELOADER_SERVICECONFIGLOCATION="/etc/cloudinfo/serviceconfig"

CMD ["cloudinfo"]
