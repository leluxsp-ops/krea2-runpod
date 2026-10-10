FROM runpod/comfyui:cuda12.8

COPY krea-entrypoint.sh /usr/local/bin/krea-entrypoint.sh
RUN chmod +x /usr/local/bin/krea-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/krea-entrypoint.sh"]
CMD []
