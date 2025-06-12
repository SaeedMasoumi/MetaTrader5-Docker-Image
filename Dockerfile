FROM ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Metatrader Docker:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="saeed"

ENV TITLE=Metatrader5
ENV WINEPREFIX="/config/.wine"
ENV WINEARCH=win64

ENV TMPDIR=/tmp
ENV TMP=/tmp
ENV TEMP=/tmp

# Update package lists and upgrade packages
RUN apt-get update && apt-get upgrade -y

# Install required packages and dependencies for Python 3.13 compilation
RUN apt-get install -y \
    wget \
    build-essential \
    zlib1g-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    curl

# Download and install Python 3.13
RUN wget https://www.python.org/ftp/python/3.13.4/Python-3.13.4.tgz \
    && tar -xf Python-3.13.4.tgz \
    && cd Python-3.13.4 \
    && ./configure --enable-optimizations --prefix=/usr/local/python3.13 \
    && make -j $(nproc) \
    && make altinstall \
    && cd .. \
    && rm -rf Python-3.13.4 Python-3.13.4.tgz

# Create virtual environment with Python 3.13 and install mt5linux
RUN mkdir -p /opt/venv \
    && /usr/local/python3.13/bin/python3.13 -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install pymt5linux pyxdg \
    && chmod -R 777 /opt/venv

# Add WineHQ repository key and APT source
RUN wget -q https://dl.winehq.org/wine-builds/winehq.key \
    && apt-key add winehq.key \
    && apt-get install -y software-properties-common \
    && apt-add-repository 'deb https://dl.winehq.org/wine-builds/debian/ bookworm main' \
    && rm winehq.key

# Add i386 architecture and update package lists
RUN dpkg --add-architecture i386 \
    && apt-get update

# Install WineHQ stable package and dependencies
RUN apt-get install --install-recommends -y \
    winehq-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy files into container
COPY /Metatrader /Metatrader
RUN chmod +x /Metatrader/start.sh
COPY /root /

EXPOSE 3000 8001
VOLUME /config
