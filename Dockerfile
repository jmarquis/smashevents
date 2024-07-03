FROM ruby:3.3.3-alpine

ARG RAILS_ENV=development

RUN apk add --update --no-cache \
      build-base \
      less \
      postgresql-dev \
      postgresql-client \
      imagemagick \
      git \
      tzdata \
      gcompat \
      inotify-tools

RUN mkdir -p /opt/rails
WORKDIR /opt/rails

COPY . ./

EXPOSE 3000
EXPOSE 3036

ENV RAILS_SERVE_STATIC_FILES=1
ENV RAILS_LOG_TO_STDOUT=1

VOLUME /opt/rails

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 CMD wget -qO /dev/null http://localhost:3000/up || exit 1

RUN ["chmod", "+x", "docker-entrypoint.sh"]
ENTRYPOINT ["/opt/rails/docker-entrypoint.sh"]

CMD ["rails", "s", "-b0"]
