FROM ruby:2.6.5 AS enroll_base

LABEL author="IdeaCrew"

ARG NODE_MAJOR
ARG NODE_VERSION
ARG BUNDLER_VERSION

# Configure app home directory
ENV HOME /enroll
RUN mkdir -p $HOME

# Install required packages/libraries
RUN apt-get update && \
    apt-get -yq dist-upgrade && \
    apt-get install -y git gcc openssl libyaml-dev libyaml-cpp-dev libyaml-cpp0.6 libffi-dev libffi6 libreadline-dev \
                       zlibc libgdbm-dev libncurses-dev autoconf fontconfig unzip zip sshpass bzip2 libxrender1 libxext6 \
                       build-essential && \
    apt-get autoremove -y

# Configure bundler and PATH, install bundler version
ENV LANG=C.UTF-8 \
    GEM_HOME=/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3
ENV BUNDLE_PATH $GEM_HOME
ENV BUNDLE_APP_CONFIG=$BUNDLE_PATH \
    BUNDLE_BIN=$BUNDLE_PATH/bin
ENV PATH /enroll/bin:$BUNDLE_BIN:$PATH

RUN gem update --system && gem install bundler:$BUNDLER_VERSION

WORKDIR $HOME

# Setting env up
ENV RAILS_ENV='development'
ENV NODE_ENV='development'

# Adding gems
#COPY Gemfile Gemfile
#COPY Gemfile.lock Gemfile.lock

COPY . $HOME

ENV NVM_DIR /nvm
RUN git clone https://github.com/nvm-sh/nvm.git $NVM_DIR
RUN chmod 744 $NVM_DIR/nvm.sh && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_MAJOR && \ 
    nvm alias default $NODE_MAJOR && \
    npm install --global yarn 

RUN . $NVM_DIR/nvm.sh && \
    bundle install && \
    yarn install --check-files
