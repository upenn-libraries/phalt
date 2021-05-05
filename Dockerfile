FROM ruby:2.6.6

ENV RACK_ENV production

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
        build-essential

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock /usr/src/app/

RUN bundle install

COPY . /usr/src/app

RUN rm -rf /var/lib/apt/lists/*

EXPOSE 9292

CMD ["bundle", "exec", "rackup"]
