ARG PDF2ZH_NEXT_BASE_IMAGE=awwaawwa/pdfmathtranslate-next:latest
FROM ${PDF2ZH_NEXT_BASE_IMAGE}

# Preload BabelDOC assets into the image layer so GUI startup
# does not need to redownload them on every container run.
# Use BabelDOC's own warmup entrypoint here: `pdf2zh --warmup`
# currently flows through pdf2zh_next.main and still asserts that
# at least one input PDF is present.
RUN babeldoc --warmup \
    && mkdir -p /opt/babeldoc-assets \
    && cp -a /root/.cache/babeldoc /opt/babeldoc-assets/babeldoc

COPY docker/pdf2zh-next-entrypoint.sh /usr/local/bin/pdf2zh-next-entrypoint
RUN chmod +x /usr/local/bin/pdf2zh-next-entrypoint

ENTRYPOINT ["/usr/local/bin/pdf2zh-next-entrypoint"]
