ARG image=
FROM $image

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's#http:[^ ]*#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev curl llvm \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev \
    libevent-dev libncurses5-dev libtinfo-dev \
    libutempter-dev bison  autotools-dev automake

ARG UNAME=test
ARG UID=
ARG GID=
RUN groupadd -g $GID -o $UNAME
RUN useradd -m -u $UID -g $GID -s /bin/bash $UNAME
USER $UID
CMD ["bash"]
WORKDIR /home/$UNAME
COPY test-script.sh /tmp/test-script.sh
