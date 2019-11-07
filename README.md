This Project aims to give you better insight of what's going on your pfSense Firewall. It's based on some heavylifting done by devopstales and opc40772. I wrapped some docker-compose glue around it, to make it a little bit easier to get up and running. It should work hasslefree with a current Linux that has docker and docker-compose. There are still a number of manual steps required.

The whole Metric approach is split into several subtopics.

| Metric type           | Stored via                | stored in       | Visualisation  |
| -------------         |:---------------------:    | --------------: | --------------: |
| pfSense IP Filter Log | Graylog                   | Elasticsearch   | Grafana |
| NTOP DPI Data         | NTOP timeseries export    | InfluxDB        | Grafana |

Optional Succicata/SNORT logs can be pushed to Elasticsearch, Graylog has ready made extractors for this, but currently this is not included in this Documentation.

# System requirements

Install docker, docker-compose and git.

# Prepare Docker

Let's pull this repo to the Server where you intend to run the Analytics front- and backend.

```
git clone https://github.com/lephisto/pfsense-graylog
cd pfsense-graylog
```

We have to adjust some Systemlimits to allow Elasticsearch to run:

```
sysctl -w vm.max_map_count=262144
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

Now spin up the stack with:

```
docker-compose up
```

This should expose you the following services externally:

| Service       | URL                   | Default Login  | Purpose |
| ------------- |:---------------------:| --------------:| --------------:|
| Graylog       | http://localhost:9000 | admin/admin |  Configure Data Ingestions and Extractors for Log Inforation |
| Grafana       | http://localhost:3000 | admin/admin | Draw nice Graphs
| Cerebro       | http://localhost:9001 |    none - provide with ES API: http://elasticsearch:9200 | ES Admin tool. Only required for setting up the Index.

Depending on your Hardware after a few minutes you should be able to connect to
your Graylog Instance on http://localhost:9000. Let's see if we can login with username "admin", password "admin".

# Indices

We now have to create the Indices in Elasticsearch for the Pfsense logs in System / Indexes

![Indices](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Indice-Pfsense-606x1024.png)

Index shard 4 and Index replicas 0, the rotation of the Index time index and the retention can be deleted, closure of an index according to the maximum number of indices or doing nothing. In my case, I set it to rotate monthly and eliminate the indexes after 12 months. In short there are many ways to establish the rotation. This index is created immediately.

![Indices](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Indices_and_Index_Sets_-_2018-04-04_20.30.42-1024x82.png)

and with [cerebro](https://github.com/lmenezes/cerebro) we can check it. You can access Cerebro under http://localhost:9001 and enter "http://elasticsearch:9200" as URL.

![Indices](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/cerebrograylogpfsense_-_2018-03-05_19.27.59-1024x454.png)

# Content Pack

This content pack includes Input rsyslog type , extractors, lookup tables, Data adapters for lockup tables and Cache for lookup tables.

We have to import the file from the Content Pack folder and for them we select in the System / Content Packs the option Import content packs to upload the file.

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Content_packs_-_2018-04-04_20.45.13-1.png)


As we see, it is add to the list

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Content_packs_-_2018-04-04_20.46.03.png)

Now we select the Pfsense content pack

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Selecting-Pfsense-Content-Pack.png)

And we apply it

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/03/Graylog_-_Content_packs_-_2018-03-09_08.47.49.png)

# Streams

We edit the stream of pfsense in Streams to associate the index that we created initially. We mark that it eliminates the coincidences for the default stream 'All message' so that only it stores it in the index of pfsense.

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Streams_-_2018-04-04_20.52.28.png)

# Cerebro

As previously explained, by default graylog for each index that is created generates its own template and applies it every time the index rotates. If we want our own templates we must create them in the same elasticsearch. We will add the field real_timestamp that will be useful when using grafana and we also convert the geo type dest_ip_geolocation and src_ip_geolocation to type geo_point to be used in the World Map panels since graylog does not use this format.

To import personalized template open cerebro and will go to more/index template

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/03/More-Cerebro.png)

We create a new template

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/03/cerebroMPCFG_-_2018-03-05_21_002.png)

In the name we fill it with pfsense-custom and open the git file that has the template and paste its content here.

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Pfsense_Custom_template.png)

And then we press the create button.

_!!! IMPORTANT: Now we will stop the graylog service to proceed to eliminate the index through Cerebro._

`#docker-compose stop graylog`

In Cerebro we stand on top of the index and unfold the options and select delete index.

![Content Pack](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Delete-index-pfsense.png)

We start the graylog service again and this will create the index with this template.

`#docker-compose stop graylog`

Pipelines

The pfsense logs that arrive at graylog, the date and the time are not sent to it, storing in the timestamp field the time they arrive at the graylog itself and this date and time is in UTC format so we must modify it so that it does not there are interpretation problems in grafana time format when displaying them.

We need to edit the pipeline of pfsense then in System/Pipelines

Source of the rule that makes the adjustment of the timestamp that we are going to use in grafana:

    rule "timestamp_pfsense_for_grafana"
     when
     has_field("timestamp")
    then
    // the following date format assumes there's no time zone in the string
     let source_timestamp = parse_date(substring(to_string(now("America/Habana")),0,23), "yyyy-MM-dd'T'HH:mm:ss.SSS");
     let dest_timestamp = format_date(source_timestamp,"yyyy-MM-dd HH:mm:ss");
     set_field("real_timestamp", dest_timestamp);
    end

We save and we have the pipeline ready to later receive the first logs.

# Pfsense

We will now prepare Pfsense to send the log logs to the graylog and for this in Status/System Logs/ Settings we will modify the options that will allow us to do so.

We go to the Remote Logging Options section and in Remote log servers we specify the ip address and the port prefixed in the content pack in the pfsense input of graylog that in this case 5442.

![Pfsense](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Pfsene-log-settings-1024x329.png)

We save the configuration.

# Graylog

We now go to graylog by selecting the pfsense stream and we will see how it is parsing the log messages creating the fields.

![Graylog](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Graylog_-_Stream_pfsense_logs_-_Search_-_2018-04-04_22.22.20-1024x452.png)

# Grafana

Graylog dashboards do not offer the possibilities to my way of seeing that grafana has so our dashboard will do in grafana.

We create the datasource in grafana which we will name Pfsense-Graylog

![Grafana](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/grafana-pfsense-datasource.png)

I share with you a [predesigned dashboard](https://grafana.com/dashboards/5420) in the official grafana site which could be imported.

![Grafana](https://www.sysadminsdecuba.com/wp-content/uploads/2018/03/import1.png)

We select Import dashboard

![Grafana](https://www.sysadminsdecuba.com/wp-content/uploads/2018/03/import2.png)

We upload the downloaded file Upload .json file and associate it with the datasource created for it.

![Grafana](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Grafana_-_Home_-_2018-04-04_22.29.58.png)

We can already see the dashboard in action.

![Grafana](https://www.sysadminsdecuba.com/wp-content/uploads/2018/04/Dashboard-in-action-970x1024.png)
