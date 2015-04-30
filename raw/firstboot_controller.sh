#!/bin/bash
set -x

FB_FLAG=/var/log/contrail/firstboot_controller.log
if [ -f ${FB_FLAG} ]; then
    exit 0
fi

if [ -f /etc/contrail/contrail-vrouter-agent.conf ]; then
    PHYS_INTF=$(grep "^physical_interface=" /etc/contrail/contrail-vrouter-agent.conf | cut -d'=' -f 2)
    dhclient -v ${PHYS_INTF}
    export HOST_ADDR=$(ifconfig ${PHYS_INTF} | grep "inet addr" | awk '{ print $2 }' | cut -d ':' -f 2)
else
    export HOST_ADDR=$(ip route get 8.8.8.8 | awk '/8.8.8.8/ {print $NF}')
fi

if [ -f /etc/rabbitmq/rabbitmq-env.conf ]; then
    sed -i "s/NODE_IP_ADDRESS=.*/NODE_IP_ADDRESS=${HOST_ADDR}/" /etc/rabbitmq/rabbitmq-env.conf
    export hostname=$(hostname) && sed -i "s/NODENAME=.*/NODENAME=$hostname/" /etc/rabbitmq/rabbitmq-env.conf
fi

# database-node conf files
if [ -f /etc/cassandra/cassandra.yaml ]; then
    sed -i "s/listen_address: 127.0.0.1/listen_address: $HOST_ADDR/" /etc/cassandra/cassandra.yaml 
    sed -i "s/rpc_address: 127.0.0.1/rpc_address: $HOST_ADDR/" /etc/cassandra/cassandra.yaml
    sed -i 's/seeds: "127.0.0.1"/seeds: "'$HOST_ADDR'"/' /etc/cassandra/cassandra.yaml
fi

if [ -f /etc/zookeeper/conf/zoo.cfg ]; then
    sed -i "s/server.1=127.0.0.1:2888:3888/server.1=${HOST_ADDR}:2888:3888/" /etc/zookeeper/conf/zoo.cfg
fi

# config-node conf files
if [ -f /etc/contrail/contrail-discovery.conf ]; then
    openstack-config --set /etc/contrail/contrail-discovery.conf DEFAULTS cassandra_server_list ${HOST_ADDR}:9160
fi 
if [ -f /etc/contrail/contrail-api.conf ]; then
    openstack-config --set /etc/contrail/contrail-api.conf DEFAULTS disc_server_ip ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-api.conf DEFAULTS zk_server_ip ${HOST_ADDR}:2181
    openstack-config --set /etc/contrail/contrail-api.conf DEFAULTS rabbit_server ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-api.conf DEFAULTS cassandra_server_list $HOST_ADDR:9160
fi
if [ -f /etc/contrail/contrail-schema.conf ]; then
    openstack-config --set /etc/contrail/contrail-schema.conf DEFAULTS disc_server_ip ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-schema.conf DEFAULTS zk_server_ip ${HOST_ADDR}:2181
    openstack-config --set /etc/contrail/contrail-schema.conf DEFAULTS cassandra_server_list $HOST_ADDR:9160
    openstack-config --set /etc/contrail/contrail-schema.conf DEFAULTS api_server_ip ${HOST_ADDR}
fi
if [ -f /etc/contrail/contrail-svc-monitor.conf ]; then
    openstack-config --set /etc/contrail/contrail-svc-monitor.conf DEFAULTS disc_server_ip ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-svc-monitor.conf DEFAULTS zk_server_ip ${HOST_ADDR}:2181
    openstack-config --set /etc/contrail/contrail-svc-monitor.conf DEFAULTS cassandra_server_list $HOST_ADDR:9160
    openstack-config --set /etc/contrail/contrail-svc-monitor.conf DEFAULTS api_server_ip ${HOST_ADDR}
fi

# control-node conf files
if [ -f /etc/contrail/contrail-control.conf ]; then
    openstack-config --set /etc/contrail/contrail-control.conf DEFAULT hostip ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-control.conf DEFAULT hostname $(hostname)
    openstack-config --set /etc/contrail/contrail-control.conf DISCOVERY server ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-control.conf IFMAP user ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-control.conf IFMAP password ${HOST_ADDR}
fi
if [ -f /etc/contrail/contrail-dns.conf ]; then
    openstack-config --set /etc/contrail/contrail-dns.conf DEFAULT hostip ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-dns.conf DEFAULT hostname $(hostname)
    openstack-config --set /etc/contrail/contrail-dns.conf DISCOVERY server ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-dns.conf IFMAP user ${HOST_ADDR}.dns
    openstack-config --set /etc/contrail/contrail-dns.conf IFMAP password ${HOST_ADDR}.dns
fi

# analytics conf files
if [ -f /etc/contrail/contrail-analytics-api.conf ]; then
    openstack-config --set /etc/contrail/contrail-analytics-api.conf host_ip ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-analytics-api.conf DEFAULTS cassandra_server_list ${HOST_ADDR}:9160
    openstack-config --set /etc/contrail/contrail-analytics-api.conf DISCOVERY disc_server_ip ${HOST_ADDR}
fi
if [ -f /etc/contrail/contrail-collector.conf ]; then
    openstack-config --set /etc/contrail/contrail-collector.conf DEFAULT cassandra_server_list ${HOST_ADDR}:9160
    openstack-config --set /etc/contrail/contrail-collector.conf DEFAULT kafka_broker_list ${HOST_ADDR}:9092
    openstack-config --set /etc/contrail/contrail-collector.conf DEFAULT hostip ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-collector.conf DISCOVERY server ${HOST_ADDR}
    openstack-config --set /etc/contrail/contrail-collector.conf DISCOVERY server ${HOST_ADDR}
fi

touch ${FB_FLAG}

