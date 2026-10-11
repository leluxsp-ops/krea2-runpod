FROM runpod/comfyui:cuda12.8

COPY krea-entrypoint.sh /usr/local/bin/krea-entrypoint.sh
COPY enable-beta57.py /usr/local/bin/enable-beta57.py
RUN chmod +x /usr/local/bin/krea-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/krea-entrypoint.sh"]
CMD []
