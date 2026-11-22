# Bauplan der Open-Source-Teile von IRL4YOU SRTLA Receiver mit unseren Aenderungen (Quelltext-Angebot nach AGPL-3.0 und MPL-2.0, siehe NOTICE.md).
# Er holt die Originale mit festem Commit, wendet die Patches aus patches/ an und fuehrt die eingebauten Tests aus. Ergebnis sind
# srtla_rec (AGPL), libsrt (MPL) und srt_server (MIT). Die Verwaltungsoberflaeche ist ein eigenes Programm und nicht Teil dieses Quelltexts.
# syntax=docker/dockerfile:1.7
ARG ALPINE_VERSION=3.24.4

FROM alpine:${ALPINE_VERSION} AS native-builder
# SRT 1.5.7 mit den offengelegten IRLServer-Kompatibilitaetsaenderungen. Alle
# aus dem Netz geladenen Quellen sind per Commit fest gepinnt.
ARG SRT_COMMIT=d487b13365205b6cd5da9d9b50868c323e255b7c
ARG SRTLA_COMMIT=877dc16e36d3fef421f9cffd345b54a526020732
ARG SLS_COMMIT=a86dd8abd3659baea8ca8315bb4842410d4bc292
ARG SRTLA_SPDLOG_COMMIT=4a5fdcb0b16f54139f3cd77d59660298e63ed58c
ARG BUILD_JOBS=4
RUN apk add --no-cache alpine-sdk cmake git linux-headers openssl-dev perl python3 tcl zlib-dev
WORKDIR /build
COPY patches/irl-srt-server-listen-callback-order.patch /tmp/irl-srt-server-listen-callback-order.patch
COPY patches/irl-srt-server-frame-stats.patch /tmp/irl-srt-server-frame-stats.patch
COPY patches/irl-srt-server-reorder-stats.patch /tmp/irl-srt-server-reorder-stats.patch
COPY patches/irl-srt-server-srtla-reorder-window.patch /tmp/irl-srt-server-srtla-reorder-window.patch
COPY patches/irlserver-srtla-broadcast-dropreq.patch /tmp/irlserver-srtla-broadcast-dropreq.patch
COPY patches/irlserver-srtla-ack-weighting.patch /tmp/irlserver-srtla-ack-weighting.patch
COPY patches/irlserver-srtla-auth-throttle.patch /tmp/irlserver-srtla-auth-throttle.patch
COPY patches/libsrt-allow-empty-ctrl.patch /tmp/libsrt-allow-empty-ctrl.patch
COPY patches/libsrt-periodic-nak-filter.patch /tmp/libsrt-periodic-nak-filter.patch
RUN git clone https://github.com/CERALIVE/srt.git srt \
 && git -C srt checkout --detach "${SRT_COMMIT}" \
 && test "$(git -C srt rev-parse HEAD)" = "${SRT_COMMIT}" \
 && git -C srt apply --check /tmp/libsrt-allow-empty-ctrl.patch \
 && git -C srt apply /tmp/libsrt-allow-empty-ctrl.patch \
 && git -C srt apply --check /tmp/libsrt-periodic-nak-filter.patch \
 && git -C srt apply /tmp/libsrt-periodic-nak-filter.patch \
 && cmake -S srt -B srt/build -DCMAKE_BUILD_TYPE=Release -DENABLE_APPS=OFF -DENABLE_SHARED=ON \
 && cmake --build srt/build --parallel "${BUILD_JOBS}" \
 && cmake --install srt/build
RUN git clone https://github.com/IRLServer/srtla.git srtla \
 && git -C srtla checkout --detach "${SRTLA_COMMIT}" \
 && test "$(git -C srtla rev-parse HEAD)" = "${SRTLA_COMMIT}" \
 && git -C srtla submodule update --init --recursive \
 && git -C srtla apply --check --ignore-space-change /tmp/irlserver-srtla-broadcast-dropreq.patch \
 && git -C srtla apply --ignore-space-change /tmp/irlserver-srtla-broadcast-dropreq.patch \
 && git -C srtla apply --check --ignore-space-change /tmp/irlserver-srtla-ack-weighting.patch \
 && git -C srtla apply --ignore-space-change /tmp/irlserver-srtla-ack-weighting.patch \
 && git -C srtla apply --check --ignore-space-change /tmp/irlserver-srtla-auth-throttle.patch \
 && git -C srtla apply --ignore-space-change /tmp/irlserver-srtla-auth-throttle.patch \
 && sed -i "s/GIT_TAG 1.9.2/GIT_TAG ${SRTLA_SPDLOG_COMMIT}/" srtla/CMakeLists.txt \
 && grep -q "GIT_TAG ${SRTLA_SPDLOG_COMMIT}" srtla/CMakeLists.txt \
 && cmake -S srtla -B srtla/build -DCMAKE_BUILD_TYPE=Release \
 && cmake --build srtla/build --parallel "${BUILD_JOBS}" \
 && srtla/build/test_metrics
RUN git clone https://github.com/IRLServer/irl-srt-server.git sls \
 && git -C sls checkout --detach "${SLS_COMMIT}" \
 && test "$(git -C sls rev-parse HEAD)" = "${SLS_COMMIT}" \
 && git -C sls apply --check /tmp/irl-srt-server-listen-callback-order.patch \
 && git -C sls apply /tmp/irl-srt-server-listen-callback-order.patch \
 && git -C sls apply --check /tmp/irl-srt-server-frame-stats.patch \
 && git -C sls apply /tmp/irl-srt-server-frame-stats.patch \
 && git -C sls apply --check /tmp/irl-srt-server-reorder-stats.patch \
 && git -C sls apply /tmp/irl-srt-server-reorder-stats.patch \
 && git -C sls apply --check /tmp/irl-srt-server-srtla-reorder-window.patch \
 && git -C sls apply /tmp/irl-srt-server-srtla-reorder-window.patch \
 && git -C sls submodule update --init --recursive \
 && cmake -S sls -B sls/build -DCMAKE_BUILD_TYPE=Release -DSLS_BUILD_TESTS=ON \
 && cmake --build sls/build --parallel "${BUILD_JOBS}" \
 && ctest --test-dir sls/build --output-on-failure --repeat until-pass:3
RUN strip --strip-unneeded \
      /usr/local/lib/libsrt.so.1.5.7 \
      /build/srtla/build/srtla_rec \
      /build/sls/build/bin/srt_server
