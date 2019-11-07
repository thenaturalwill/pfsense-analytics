#!/bin/bash
sed -i 's/${DS_PFS_GRAYLOG}/pfsensefw/g' provisioning/dashboards/firewall.json
sed -i 's/${DS_NTOP-CLUSTER}/ntop/g' provisioning/dashboards/ndpi.json
