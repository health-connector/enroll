# # Note: You can use any Debian/Ubuntu based image you want. 
# FROM mcr.microsoft.com/devcontainers/base:3.4-trixie

# Published devcontainers tags use $minor-trixie (e.g. 3.4-trixie), not 3.4.7-trixie
ARG RUBY_VARIANT=3.4-trixie

FROM mcr.microsoft.com/devcontainers/ruby:${RUBY_VARIANT}

# Make compose-provided overrides functional (keep in sync with .ruby-version and Gemfile.lock "BUNDLED WITH")
ARG RVM_OVERRIDE=3.4.7
ARG BUNDLER_VERSION_OVERRIDE=2.5.23

# Add Yarn apt repository using keyrings (apt-key is removed on Debian trixie)
RUN apt-get update -qq \
    && apt-get install -yq --no-install-recommends gnupg \
    && curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg \
      | gpg --dearmor -o /usr/share/keyrings/yarn-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" \
      | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && truncate -s 0 /var/log/*log

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends libsodium23

ARG NODE_VERSION="none"
RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

RUN su vscode -c "/bin/bash -l -c '. /etc/profile.d/rvm.sh && rvm install ${RVM_OVERRIDE}'"
RUN su vscode -c '/bin/bash -l -c ". /etc/profile.d/rvm.sh && rvm gemset create enroll"'
RUN su vscode -c "/bin/bash -l -c '. /etc/profile.d/rvm.sh && rvm use ${RVM_OVERRIDE}@enroll'"
RUN su vscode -c "/bin/bash -l -c '. /etc/profile.d/rvm.sh && rvm use ${RVM_OVERRIDE}@enroll && gem install bundler -v ${BUNDLER_VERSION_OVERRIDE} --no-document'"

USER vscode

# [Optional] Uncomment this section to install additional OS packages.

# [Optional] Uncomment this line to install additional gems.
# RUN sudo gem install bundler -v 1.17.3

# RUN gem update --system 3.3.26
