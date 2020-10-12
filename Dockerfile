FROM docker/compose:debian-1.27.4 as registry-builder

# Install some utilities to make validation of the issue easier, we'll be needing nslookup and curl
RUN apt-get update && apt-get install -y dnsutils curl

WORKDIR /tmp/context

CMD bash -xc "                                                                                              \
    (                                                                                                       \
        docker login --username $DOCKER_USERNAME --password $DOCKER_PASSWORD http://bootstrap-registry:5000 \
        && docker-compose push                                                                              \
    );                                                                                                      \
    docker logout http://bootstrap-registry:5000 ;                                                          \
"

FROM registry:2.7.1 as docker-registry
FROM alpine:3.8 as bootstrap-registry

RUN set -ex && apk add --no-cache ca-certificates apache2-utils

COPY --from=docker-registry /bin/registry /bin/registry
COPY --from=docker-registry /entrypoint.sh /entrypoint.sh

COPY ./config.yml /etc/docker/registry/config.yml

EXPOSE 5000

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/etc/docker/registry/config.yml" ]