# Beginnen Sie mit einem geeigneten Basis-Image für Ubuntu
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Argumente für den Benutzer (Codespaces setzt diese oft, aber hier zur Klarheit)
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Installieren Sie notwendige Abhängigkeiten für Flutter
# (git, curl, unzip etc. sind oft schon im base:ubuntu, aber zur Sicherheit hier expliziter)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    git \
    curl \
    unzip \
    xz-utils \
    libglu1-mesa \
    # Zusätzliche Abhängigkeiten, die Flutter Web oder Linux Desktop benötigen könnten
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK Installation
# Wir installieren es im Home-Verzeichnis des Benutzers
USER $USERNAME
WORKDIR /home/$USERNAME

# Klonen des Flutter SDKs vom stabilen Channel
RUN git clone https://github.com/flutter/flutter.git --depth 1 --branch stable /home/$USERNAME/flutter

# Hinzufügen von Flutter zum PATH
ENV PATH="/home/$USERNAME/flutter/bin:${PATH}"

# Führen Sie Flutter Doctor aus und laden Sie Web-Abhängigkeiten vorab herunter
# um sicherzustellen, dass alles beim ersten Start bereit ist.
RUN flutter doctor -v && flutter precache --web

# Setzen Sie den Standardarbeitsbereich für das Projekt
WORKDIR /workspaces