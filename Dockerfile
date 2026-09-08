FROM	rust:1.97-trixie AS rodger-build

RUN	apt-get update \
	&& apt-get install git -y \
	&& mkdir -p /rodger-build \
	&& git clone --depth 1 --branch 0.9.0 https://codeberg.org/raidriar/Rodger /rodger-build/Rodger \
	&& cd /rodger-build/Rodger \
	&& tar -czvf /rodger-build/rodger.tar.gz . \
	&& cargo build --release \
	&& mkdir -p /rusty-reso-ws-tty-build \
	&& git clone https://gitlab.peacefulbeast.eu/TomTam/rusty-reso-ws-tty /rusty-reso-ws-tty-build/rusty-reso-ws-tty \
	&& cd /rusty-reso-ws-tty-build/rusty-reso-ws-tty \
	&& cargo build --release

FROM	debian:trixie-slim

LABEL	author="Voxel Bone Cloud" maintainer="github@voxelbone.cloud"
LABEL	org.opencontainers.image.source=https://github.com/voxelbonecloud/resonite-headless-docker
LABEL	org.opencontainers.image.description="Docker image based on Debian trixie Slim image with .NET 10 for hosting Resonite Headless servers. Supports automatic modding of the Headless."
LABEL	org.opencontainers.image.licenses=MIT-0
LABEL	org.opencontainers.image.authors="Voxel Bone Cloud"

RUN	apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y locales \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	&& update-locale LANG=en_US.UTF-8 \
	&& update-locale LANG=en_GB.UTF-8 \
	&& apt-get install curl -y \
	&& curl https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb \
	&& dpkg -i /tmp/packages-microsoft-prod.deb \
	&& rm /tmp/packages-microsoft-prod.deb \
	&& dpkg --add-architecture i386 \
	&& apt-get update \
	&& apt-get install git lib32gcc-s1 libfreetype6 dotnet-runtime-10.0 libmsquic gettext-base btop -y \
	&& rm -r /var/lib/apt/lists/* \
	&& groupadd -g 1000 container \
	&& useradd -u 1000 -g 1000 -m -d /home/container -s /bin/bash container

ENV	LANG=en_GB.UTF-8

COPY	./scripts /scripts
 
COPY	--from=rodger-build /rodger-build/Rodger/target/release/rodger /tools/rodger/rodger
COPY	--from=rodger-build /rodger-build/rodger.tar.gz /tools/rodger/rodger.tar.gz
COPY	--from=rodger-build /rusty-reso-ws-tty-build/rusty-reso-ws-tty /tools/rusty-reso-ws-tty

RUN	chmod +x /scripts/*

RUN	mkdir /Logs \
	&& chown -R container:container /Logs

RUN	mkdir /Config \
	&& chown -R container:container /Config

RUN	mkdir -p /cofigs/Rodger \
	&& mkdir -p /home/container/.cache \
	&& chown -R container:container /home/container/.cache \
	&& mkdir .p /configs

COPY    ./configs/ /configs

COPY	./templates/rodger/config.ron configs/Rodger/config.ron 
COPY	./templates/engineconfig/Config.json /tools/Config.json
COPY	./templates/engineconfig/ConfigPortrange.json /tools/ConfigPortrange.json

RUN	mkdir -p /RML /RML/rml_mods /RML/rml_libs /RML/rml_config \
	&& chown -R container:container /RML
USER	container

USER	container
ENV	USER=container 
ENV	HOME=/home/container
ENV	DEBIAN_FRONTEND=noninteractive

WORKDIR	/home/container

STOPSIGNAL SIGINT

ENTRYPOINT ["/scripts/update-resonite.sh"]
CMD ["/scripts/launch-resonite.sh"]
