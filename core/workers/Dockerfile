FROM swift:6.1

# Build configuration argument (no default)
ARG SWIFT_BUILD_CONFIG
ENV SWIFT_BUILD_CONFIG=${SWIFT_BUILD_CONFIG}

# Dependencies
RUN apt-get update && apt-get install -y libssl-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Package files first to cache dependency resolution
COPY Package.swift Package.resolved ./
RUN --mount=type=cache,target=/tmp/.build \
    --mount=type=cache,target=/root/.cache/swift-pm \
    swift package resolve

# Copy the source and build
COPY . .

# Build with caches and copy the result into the image
RUN --mount=type=cache,target=/tmp/.build \
    --mount=type=cache,target=/root/.cache/swift-pm \
    swift build --configuration ${SWIFT_BUILD_CONFIG}
