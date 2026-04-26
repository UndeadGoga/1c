# =============================================================================
# Dockerfile для RAS 1С:Предприятие 8.3 (Community Edition)
# =============================================================================
# Использует уже подготовленные файлы из 1c-server/dist/opt-1cv8/
# =============================================================================

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=ru_RU.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates libicu70 libwebkit2gtk-4.0-37 \
    && locale-gen ru_RU.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Копируем уже установленные файлы 1С (подготовленные на хосте)
COPY 1c-server/dist/opt-1cv8/ /opt/1cv8/
RUN chown -R root:root /opt/1cv8

# Симлинки на бинарники
RUN for bin in ras rac ragent rmngr rphost; do \
        src=$(find /opt/1cv8/x86_64 -maxdepth 2 -name "$bin" -type f -executable 2>/dev/null | head -n 1); \
        if test -n "$src"; then \
            ln -sf "$src" "/usr/local/bin/$bin"; \
        fi; \
    done

COPY 1c-ras/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1545
ENTRYPOINT ["/entrypoint.sh"]
