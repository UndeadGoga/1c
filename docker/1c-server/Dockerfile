# =============================================================================
# Dockerfile для 1С:Предприятие 8.3 Community Edition
# =============================================================================
# Требует предварительной установки 1С на хосте и копирования файлов:
#   sudo cp -r /opt/1cv8 docker/1c-server/dist/opt-1cv8
# =============================================================================

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# Зависимости (только бесплатные пакеты из репозитория Ubuntu)
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales ca-certificates wget curl \
    libwebkit2gtk-4.0-37 libgtk-3-0 libenchant-2-2 libhyphen0 libicu70 \
    libgsf-1-114 libgee-0.8-2 libsqlite3-0 libxslt1.1 libxerces-c3.2 \
    unixodbc odbcinst odbc-postgresql \
    ttf-mscorefonts-installer fontconfig imagemagick libmagickwand-6.q16-6 \
    && locale-gen ru_RU.UTF-8 \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

# Пользователь 1С
RUN groupadd -r grp1cv8 --gid=2001 \
    && useradd -r -g grp1cv8 --uid=2001 usr1cv8 \
    && mkdir -p /var/lib/1c /var/log/1c /opt/1cv8 \
    && chown -R usr1cv8:grp1cv8 /var/lib/1c /var/log/1c /opt/1cv8

# Копируем уже установленные файлы 1С (подготовленные на хосте)
COPY dist/opt-1cv8/ /opt/1cv8/
RUN chown -R usr1cv8:grp1cv8 /opt/1cv8

# Симлинки на бинарники
RUN for bin in ragent rmngr rphost ras rac; do \
        src=$(find /opt/1cv8/x86_64 -maxdepth 2 -name "$bin" -type f -executable 2>/dev/null | head -n 1); \
        if test -n "$src"; then \
            ln -sf "$src" "/usr/local/bin/$bin"; \
        fi; \
    done

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1540 1541 1560-1591
USER usr1cv8
ENTRYPOINT ["/entrypoint.sh"]
