#!/bin/bash


# Brief: Configure all network interfaces and connects them into the OVS bridges 
# and 
# Params:
#   - $1: name of the container
#   - $2: Tag of the subnet
#   - $3: Host ip part
#   - $4: Name of the bridge to connect to the containers 
#   - $5: IF current conteiner is a linux cliente, then  $5 represents name of the client behaviour file
# Example:
#   - configure_host mailserver 100 1 br-int 
configure_host(){
    ## Add container to namespace. Available on: https://www.thegeekdiary.com/how-to-access-docker-containers-network-namespace-from-host/
    pid=$(docker inspect -f '{{.State.Pid}}' $1)
    mkdir -p /var/run/netns/
    ln -sfT /proc/$pid/ns/net /var/run/netns/$1

    # If %5 is not NULL, then execute the commands below
    if [ ! -z $5 ]; then
    docker cp printersip/$2 $1:/home/debian/automation/packages/system/printerip
    docker cp client_behaviour/$5 $1:/home/debian/automation/packages/system/config.ini
    docker cp serverconfig.ini $1:/home/debian/automation/packages/system/serverconfig.ini
    fi

    ## Add interface on container and host
    ip link add veth$2.$3 type veth peer name vethsubnet$2
    ip link set veth$2.$3 up

    ## Connect interfaces into the container subspace to the bridge
    ip link set vethsubnet$2 netns $1
    ip -n $1 link set vethsubnet$2 up
    ovs-vsctl add-port $4 veth$2.$3

    ## Add ip addressses and routes
    ip -n $1 route add 192.168.$SSUBNET.0/24 dev vethsubnet$2
    ip -n $1 route add 192.168.$MSUBNET.0/24 dev vethsubnet$2
    ip -n $1 route add 192.168.$OSUBNET.0/24 dev vethsubnet$2
    ip -n $1 route add 192.168.$DSUBNET.0/24 dev vethsubnet$2
    ip -n $1 addr add 192.168.$2.$3/24 dev vethsubnet$2
    ip netns exec $1 route add default gw 192.168.$2.100
}