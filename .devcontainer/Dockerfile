# # Note: You can use any Debian/Ubuntu based image you want. 
# FROM mcr.microsoft.com/devcontainers/base:bullseye

ARG RUBY_VARIANT=2-bullseye

FROM mcr.microsoft.com/vscode/devcontainers/ruby:0-${RUBY_VARIANT}

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends libsodium23 python2.7 python-is-python2 yarn 

ARG NODE_VERSION="none"
RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

RUN su vscode -c '/bin/bash -l -c ". /etc/profile.d/rvm.sh && rvm install 2.6.5"'
RUN su vscode -c '/bin/bash -l -c ". /etc/profile.d/rvm.sh && rvm use 2.6.5"'

USER vscode

# [Optional] Uncomment this section to install additional OS packages.

# [Optional] Uncomment this line to install additional gems.
# RUN sudo gem install bundler -v 1.17.3

# RUN gem update --system 3.3.26
