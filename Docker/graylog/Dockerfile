FROM graylog/graylog:3.1
# Probably a bad idea, but it works for now
USER root
ENV GRAYLOG_PLUGIN_DIR=/etc/graylog/server/
RUN mkdir -pv /etc/graylog/server/
COPY ./getGeo.sh /etc/graylog/server/
RUN chmod +x /etc/graylog/server/getGeo.sh && /etc/graylog/server/getGeo.sh
USER graylog
