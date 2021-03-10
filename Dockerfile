FROM ruby:2.4.0

ENV RACK_ENV production

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AA8E81B4331F7F50 && \
    apt-get update && apt-get install -qq -y --no-install-recommends \
        build-essential

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock /usr/src/app/

RUN bundle install

COPY . /usr/src/app

RUN rm -rf /var/lib/apt/lists/*

EXPOSE 9292

CMD ["bundle", "exec", "rackup"]
