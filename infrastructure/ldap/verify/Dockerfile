FROM debian:bullseye-slim
LABEL maintainer="Uwe Eisele <code@uweeisele.eu>"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y install vim \
    && apt-get clean

RUN apt-get update \
    && apt-get -y install curl ldnsutils dnsutils \
    && apt-get clean

RUN apt-get update \
    && apt-get -y install ldap-utils libnss-ldap libsasl2-modules-gssapi-mit krb5-user \
    && apt-get clean

#RUN apt-get update \
#    && apt-get -y install sssd realmd samba-common packagekit adcli \
#    && apt-get clean

ENV DEBIAN_FRONTEND=