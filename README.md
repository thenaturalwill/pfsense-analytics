This Project aims to give you better insight of what's going on your pfSense Firewall. It's based on some heavylifting done by devopstales and opc40772. I wrapped some docker-compose glue around it, to make it a little bit easier to get up and running. It should work hasslefree with a current Linux that has docker and docker-compose. There are still a number of manual steps required.

The whole Metric approach is split into several subtopics.

| Metric type           | Stored via                | stored in       | Visualisation  |
| -------------         |:---------------------:    | --------------: | --------------: |
| pfSense IP Filter Log | Graylog                   | Elasticsearch   | Grafana |
| NTOP DPI Data         | NTOP timeseries export    | InfluxDB        | Grafana |

Optional Succicata/SNORT logs can be pushed to Elasticsearch, Graylog has ready made extractors for this, but currently this is not included in this Documentation.

This walkthrough has been made with a fresh install of Ubuntu 18.04 Bionic but should work flawless with any debian'ish linux distro.

# System requirements

Install docker, docker-compose and git.

```
sudo apt install docker.io docker-compose git
```

# 1. Prepare Docker

Let's pull this repo to the Server where you intend to run the Analytics front- and backend.

```
git clone https://github.com/lephisto/pfsense-analytics
cd pfsense-analytics
```

We have to adjust some Systemlimits to allow Elasticsearch to run:

```
sudo sysctl -w vm.max_map_count=262144
```

to make it permanent edit /etc/sysctl.conf and add the line:

```
vm.max_map_count=262144
```

Next we edit the docker-compose.yml file and set some values:

The URL you want your Graylog to be available under:
- GRAYLOG_HTTP_EXTERNAL_URI (eg: http://localhost:9000)

A Salt for encrypting your Gralog passwords
- GRAYLOG_PASSWORD_SECRET (Change that _now_)


Now We need to pull the GeoIP Database from maxmind:

```
curl --output mm.tar.gz https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
tar xfzv mm.tar.gz
```

.. symlink (take correct directory, includes date..):

```
ln -s GeoLite2-City_20191105/GeoLite2-City.mmdb .
```


Finally, spin up the stack with:

```
sudo docker-compose up
```

This should expose you the following services externally:

| Service       | URL                   | Default Login  | Purpose |
| ------------- |:---------------------:| --------------:| --------------:|
| Graylog       | http://localhost:9000 | admin/admin |  Configure Data Ingestions and Extractors for Log Inforation |
| Grafana       | http://localhost:3000 | admin/admin | Draw nice Graphs
| Cerebro       | http://localhost:9001 |    none - provide with ES API: http://elasticsearch:9200 | ES Admin tool. Only required for setting up the Index.

Depending on your Hardware after a few minutes you should be able to connect to
your Graylog Instance on http://localhost:9000. Let's see if we can login with username "admin", password "admin".

# 2. Initial Index creation

Next we have to create the Indices in Elasticsearch for the pfSense logs in System / Indices

![Indices](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Indice-Pfsense-606x1024.png)

Index shard 4 and Index replicas 0, the rotation of the Index time index and the retention can be deleted, closure of an index according to the maximum number of indices or doing nothing. In my case, I set it to rotate monthly and eliminate the indexes after 12 months. In short there are many ways to establish the rotation. This index is created immediately.

![Indices](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Indices_and_Index_Sets_-_2018-04-04_20.30.42-1024x82.png)

# 3. GeoIP Plugin activation

In Graylog go to System->Configurations and:

1. Change the order by Message processors, to have "GeoIP Resolver" on the bottom
2. Update Plugins an denable Geo-Location Processor


# 4. Content Packs

### Custom Content Pack

This content pack includes Input rsyslog type , extractors, lookup tables, Data adapters for lockup tables and Cache for lookup tables.

We can take it from the Git directory or sideload it from github to the Workstation you do the deployment on:

https://raw.githubusercontent.com/lephisto/pfsense-analytics/master/pfsense_content_pack/graylog3/pfanalytics.json


Once it's uploaded, press Install.

# 4. Assign Streams

Now edit then Streams: Assign your Index pfsense in Streams to associate the index that we created initially. We mark that it eliminates the coincidences for the default stream 'All message' so that only it stores it in the index of pfsense.

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Streams_-_2018-04-04_20.52.28.png)

# 5. Cerebro

This part might be a little bit confusing, so read carefully!

As previously explained, by default graylog for each index that is created generates its own template and applies it every time the index rotates. If we want our own templates we must create them in the same elasticsearch. We will convert the geo type dest_ip_geolocation and src_ip_geolocation to type geo_point to be used in the World Map panels since graylog does not use this format.

Get the Index Template from the GIT repo you cloned or sideload it from:

https://raw.githubusercontent.com/lephisto/pfsense-graylog/master/Elasticsearch_pfsense_custom_template/pfsense_custom_template_es6.json

To import personalized template open cerebro and will go to more/index template

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/03/More-Cerebro.png)

We create a new template

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/03/cerebroMPCFG_-_2018-03-05_21_002.png)

In the name we fill it with pfsense-custom and open the git file that has the template and paste its content here.

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Pfsense_Custom_template.png)

And then we press the create button.

_!!! IMPORTANT: Now we will stop the graylog service to proceed to eliminate the index through Cerebro._

`sudo docker-compose stop graylog`

In Cerebro we stand on top of the index and unfold the options and select delete index.

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Delete-index-pfsense.png)

We start the graylog service again and this will recreate the index with this template.

`sudo docker-compose start graylog`


# 6. Configure pfSense

We will now prepare Pfsense to send logs to graylog and for this in Status/System Logs/ Settings we will modify the options that will allow us to do so.

We go to the Remote Logging Options section and in Remote log servers we specify the ip address and the port prefixed in the content pack in the pfsense input of graylog that in this case 5442.

![Pfsense](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Pfsene-log-settings-1024x329.png)

We save the configuration.

# Check Graylog

We now go to graylog by selecting the pfsense stream and we will see how it is parsing the log messages creating the fields.

![Graylog](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Stream_pfsense_logs_-_Search_-_2018-04-04_22.22.20-1024x452.png)

# Check Grafana

Dashboards and Datasource are auto-provisioned to Grafana. Log in at http://localhost:9000 with admin/admin and you should see your Firewall Logs pouring in.

# DPI

Now that we have the Firewall logs we want to get some Intel about legit Traffic on our Network.

- On your pfSense go to System->Package Manager->Available Packages and install ntopng.
- Head to Diagnostics -> ntopng Settings and do basic Configuration
- Update GeoIP Data there as well. (Install "PFSENSE-9211: Fix GeoIP DB" if it fails)
- Go to Diagnostics -> ntopng Settings and log in to ntopng
- Go to Settings -> Preferences -> timeseries

Configure according your needs, I propose following Settings:

| Setting           | Value                 | remarks |
| -------------     |:---------------------:|:---------------------:|
| Timeseries Driver | InfluxDB ||
| InfluxDB URL      | http://yourdockerserverip:8086   | |
| InfluxDB Datebase   | ndpi   ||
| InfluxDB Authentication   | off  | unless you have enabled.|
| InfluxDB Storage   | 365d   |   |
| Interface TS: Traffic   | on   |   |
| Interface TS: L7 Applications   | per Protocol   |   |
| Local Host Timeseries: Traffic  | on   |   |
| Local Host Timeseries: L7 Applications   | per Protocol   |   |
| Device Timeseries: Traffic  | on   |   |
| Device Timeseries: L7 Applications   | per Category   |   |
| Device Timeseries: Retention | 30d  |   |
| Other Timeseries: TCP Flags  | off  |   |
| Other Timeseries: TCP OfO,Lost,Retran  | off  |   |
| Other Timeseries: VLANs  | on  |   |
| Other Timeseries: Autonomous Systems | on  |   |
| Other Timeseries: Countries | on  |   |
| Datebase Top Talker Storage   | 365d  |   |


That should do it. Check your DPI Dashboard and enjoy :)
