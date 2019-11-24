curl --output ${GRAYLOG_PLUGIN_DIR}/mm.tar.gz https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
tar zxvf ${GRAYLOG_PLUGIN_DIR}/mm.tar.gz -C ${GRAYLOG_PLUGIN_DIR} --strip-components=1
