FROM ruby:3.4.1-slim

ARG RAILS_ENV=development

RUN apt-get update && apt-get install -y --no-install-recommends \
  bash \
  curl \
  build-essential \
  less \
  libpq-dev \
  postgresql-client \
  imagemagick \
  git \
  tzdata \
  inotify-tools \
  libjemalloc2 \
  libprotobuf-dev \
  protobuf-compiler \
  wget \
  unzip \
  vim \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

ENV LD_PRELOAD=libjemalloc.so.2

RUN mkdir -p /opt/rails
WORKDIR /opt/rails

COPY . ./

EXPOSE 3000
EXPOSE 3391

ENV RAILS_SERVE_STATIC_FILES=1
ENV RAILS_LOG_TO_STDOUT=1
ENV DISCORDRB_NONACL=1

VOLUME /opt/rails

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 CMD wget -qO /dev/null http://localhost:3000/up || exit 1

RUN ["chmod", "+x", "docker-entrypoint.sh"]
ENTRYPOINT ["/opt/rails/docker-entrypoint.sh"]

CMD ["rails", "s", "-b0"]
