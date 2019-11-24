curl --output /etc/graylog/server/mm.tar.gz https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
tar zxvf /etc/graylog/server/mm.tar.gz -C /etc/graylog/server/ --strip-components=1
