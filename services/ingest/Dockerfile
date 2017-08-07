ARG CRYSTAL_VERSION=0.23.0
FROM crystallang/crystal:${CRYSTAL_VERSION}

# Install dependancies
COPY shard.yml /app/
#COPY shard.lock /app/
WORKDIR /app
RUN crystal deps

# Build the service
COPY . /app
RUN crystal build src/ingest.cr --release

# Launch
CMD ["./ingest"]
