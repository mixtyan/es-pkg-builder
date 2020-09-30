FROM ubuntu:16.04 as intermediate
RUN cp /etc/apt/sources.list /etc/apt/sources.list.bak \
    && echo "deb http://mirrors.aliyun.com/ubuntu/ xenial main restricted universe multiverse \
    && deb http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted universe multiverse \
    && deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted universe multiverse \
    && deb http://mirrors.aliyun.com/ubuntu/ xenial-proposed main restricted universe multiverse \
    && deb http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse \
    && deb-src http://mirrors.aliyun.com/ubuntu/ xenial main restricted universe multiverse \
    && deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted universe multiverse \
    && deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted universe multiverse \
    && deb-src http://mirrors.aliyun.com/ubuntu/ xenial-proposed main restricted universe multiverse \
    && deb-src http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse" > /etc/apt/sources.list
RUN apt-get update \
    && apt-get install -y software-properties-common python-software-properties \
    && apt-add-repository ppa:git-core/ppa \
    && apt-get update \
    && apt-get install -y zip unzip aptitude \
    && aptitude install perl-base=5.22.1-9 \
    && aptitude install -y git
ARG SSH_PRIVATE_KEY
RUN mkdir /root/.ssh/ \
    && echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa \
    && chmod 600 /root/.ssh/id_rsa \
    && touch /root/.ssh/known_hosts \
    && ssh-keyscan coding.codeages.work >> /root/.ssh/known_hosts
RUN cd / \
    && git clone -b master git@coding.codeages.work:corporate-training/edusoho.git

FROM ubuntu:16.04
COPY --from=intermediate /edusoho /edusoho
COPY --from=intermediate /etc/apt/sources.list /etc/apt/sources.list
RUN apt-get update \
    && apt-get install -y software-properties-common \
    && LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y php-pear php7.1-cli php7.1-common php7.1-curl \
    php7.1-fpm php7.1-json php7.1-mbstring php7.1-mcrypt \
    php7.1-mysql php7.1-opcache php7.1-zip php7.1-intl php7.1-gd php7.1-xml \
    && apt-get install -y curl \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash -\
    && echo "deb https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb_10.x trusty main \
deb-src https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb_10.x/ trusty main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm config set registry https://registry.npm.taobao.org \
    && npm install -g yarn \
    && yarn config set registry https://registry.npm.taobao.org \
    && apt-add-repository ppa:git-core/ppa \
    && apt-get update \
    && apt-get install -y zip unzip aptitude \
    && aptitude install perl-base=5.22.1-9 \
    && aptitude install -y git \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]
