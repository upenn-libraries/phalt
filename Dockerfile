FROM ruby:2.4.0

MAINTAINER Kate Lynch <katherly@upenn.edu>

ENV RACK_ENV production

EXPOSE 9292

RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
         build-essential

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock /usr/src/app/

RUN bundle install

COPY . /usr/src/app

RUN rm -rf /var/lib/apt/lists/*

CMD ["bundle", "exec", "rackup"]
