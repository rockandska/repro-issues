#!/bin/bash

cat << EOF

#######################
# Get Haproxy version #
#######################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  echo -e "\n${c} :\n"
  docker exec ${c} haproxy -v
done

cat << EOF

######################
# IP's of containers #
######################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9 redis-1-centos-7 redis-2-centos-7 redis-3-centos-7;do
  docker inspect $c | egrep -H --label "${c}" '"IPAddress": "[0-9]{1,3}\.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}"'
done

cat << EOF

#################################################
# Apply Haproxy conf (with 'tcp-check connect') #
#################################################

EOF

read -r -d '' HAPROXY_CONF <<'EOF'
global
  log /dev/log local2
  stats socket /var/lib/haproxy/stats.sock mode 660 level admin process 1
  stats timeout 30s
  user haproxy
  group haproxy
  daemon
  maxconn 200000

defaults
  log global
  mode tcp
  option  tcplog
  timeout connect 5000
  timeout client 50000
  timeout server 50000

frontend ft_redis
  bind :6379 name redis
  default_backend bk_redis
  mode tcp

backend bk_redis
  mode tcp
  option tcp-check
  tcp-check connect
  tcp-check send PING\r\n
  tcp-check expect string +PONG
  tcp-check send info\ replication\r\n
  tcp-check expect string role:master
  tcp-check send QUIT\r\n
  tcp-check expect string +OK
  server redis-1-centos-7 redis-1-centos-7:6379 check inter 1s
  server redis-2-centos-7 redis-2-centos-7:6379 check inter 1s
  server redis-3-centos-7 redis-3-centos-7:6379 check inter 1s
EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  docker exec ${c} systemctl stop haproxy || true
  docker exec ${c} pkill haproxy
  docker exec ${c} bash -c "echo '${HAPROXY_CONF}' > /etc/haproxy/haproxy.cfg"
  docker exec ${c} bash -c "strace -tt haproxy -f /etc/haproxy/haproxy.cfg" &> strace_${c}_with_tcp_connect.trace
  echo "${c}.... done"
done

cat << EOF

########################
# Haproxy conf applied #
########################

EOF

docker exec proxy-2-debian-9 cat /etc/haproxy/haproxy.cfg

if ! diff <(docker exec proxy-1-centos-7 cat /etc/haproxy/haproxy.cfg) <(docker exec proxy-2-debian-9 cat /etc/haproxy/haproxy.cfg);then
  1>&2 echo "/!\ Diff in conf ! exit"
  exit 1
fi

sleep 5

#cat << EOF
#
#####################
## Systemctl status #
#####################
#
#EOF
#
#for c in proxy-1-centos-7 proxy-2-debian-9;do
#  echo -e "\nsystemctl for container ${c}\n"
#  docker exec ${c} systemctl status -l haproxy
#done

cat << EOF

#################################################
# Get Redis nodes status from inside containers #
#################################################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  echo -e "\nInside container: ${c}\n"
  for r in redis-1-centos-7 redis-2-centos-7 redis-3-centos-7;do
    echo -e "\n\t ${r} :\n";
    docker exec ${c} bash -c "echo -e 'PING\r\ninfo replication\r\nQUIT' | nc ${r} 6379" | sed 's/^/            /'
  done
done

cat << EOF

####################
# Get actual stats #
####################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  echo -en "Stats for : ${c}\n"
  docker exec ${c} bash -c 'echo "show stat" | socat /var/lib/haproxy/stats.sock stdio'
done


cat << EOF

#################################################
# Capture traffic ('tcp-check connect' enabled) #
#################################################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  docker exec ${c} bash -c "timeout 30s tcpdump -nps0 -i eth0 tcp port 6379" > healthcheck-${c}-with-tcp-check.cap &
done

wait

cat << EOF

####################################################
# Apply Haproxy conf (without 'tcp-check connect') #
####################################################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  docker exec ${c} systemctl stop haproxy || true
  docker exec ${c} pkill haproxy
  docker exec ${c} bash -c "echo '${HAPROXY_CONF}' | sed -n '/tcp-check connect/!p'  > /etc/haproxy/haproxy.cfg"
  docker exec ${c} bash -c "strace -tt haproxy -f /etc/haproxy/haproxy.cfg" &> strace_${c}_without_tcp_connect.trace
  echo "${c}.... done"
done

cat << EOF

########################
# Haproxy conf applied #
########################

EOF

docker exec proxy-2-debian-9 cat /etc/haproxy/haproxy.cfg

if ! diff <(docker exec proxy-1-centos-7 cat /etc/haproxy/haproxy.cfg) <(docker exec proxy-2-debian-9 cat /etc/haproxy/haproxy.cfg);then
  1>&2 echo "/!\ Diff in conf ! exit"
  exit 1
fi

sleep 5

#cat << EOF
#
#####################
## Systemctl status #
#####################
#
#EOF
#
#for c in proxy-1-centos-7 proxy-2-debian-9;do
#  echo -e "\nsystemctl for container ${c}\n"
#  docker exec ${c} systemctl status -l haproxy
#done

cat << EOF

#################################################
# Get Redis nodes status from inside containers #
#################################################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  echo -e "\nInside container: ${c}\n"
  for r in redis-1-centos-7 redis-2-centos-7 redis-3-centos-7;do
    echo -e "\n\t ${r} :\n";
    docker exec ${c} bash -c "echo -e 'PING\r\ninfo replication\r\nQUIT' | nc ${r} 6379" | sed 's/^/            /'
  done
done

cat << EOF

####################
# Get actual stats #
####################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  echo -en "Stats for : ${c}\n"
  docker exec ${c} bash -c 'echo "show stat" | socat /var/lib/haproxy/stats.sock stdio'
done



cat << EOF

##################################################
# Capture traffic ('tcp-check connect' disabled) #
##################################################

EOF

for c in proxy-1-centos-7 proxy-2-debian-9;do
  docker exec ${c} bash -c "timeout 30s tcpdump -nps0 -i eth0 tcp port 6379" > healthcheck-${c}-without-tcp-check.cap &
done

wait
