#!/bin/bash

WHO=`whoami`
if [ $WHO != "root" ]
then
echo
echo "Execute this scipt as user root"
echo
exit 1
fi

apt-get -y install nodejs npm wget net-tools

rm -f /usr/local/sbin/start-sonos-smb
cat >> /usr/local/sbin/start-sonos-smb << EOF
#!/bin/bash
cd /etc/node-smb-server
npm start &
EOF

rm -f /etc/systemd/system/rc-local.service
cat >> /etc/systemd/system/rc-local.service << EOF
[Unit]
 Description=/etc/rc.local Compatibility
 ConditionPathExists=/etc/rc.local

[Service]
 Type=forking
 ExecStart=/etc/rc.local start
 TimeoutSec=0
 StandardOutput=tty
 RemainAfterExit=yes
 SysVStartPriority=99

[Install]
 WantedBy=multi-user.target
EOF

systemctl enable /etc/systemd/system/rc-local.service

mv /etc/rc.local /etc/rc.local-orig
cat >> /etc/rc.local << EOF
#!/bin/bash

/bin/rm -f /var/log/node-smb-server/*
/usr/local/sbin/start-sonos-smb &
exit 0
EOF

rm -f /usr/local/sbin/smb-pacemaker
cat <<'EOF' >> /usr/local/sbin/smb-pacemaker
#!/bin/bash

STATUS=$(netstat -tulpn | grep ":445 " | wc -l)

if test $STATUS -ne 1; then
killall node
/usr/local/sbin/start-sonos-smb &
fi
EOF

chmod +rx /etc/rc.local
chmod +rx /usr/local/sbin/start-sonos-smb
chmod +rx /usr/local/sbin/smb-pacemaker

mkdir /var/log/node-smb-server
chmod ugo+w /var/log/node-smb-server/
rm -Rf /etc/node-smb-server
mkdir /etc/node-smb-server
cd /etc/node-smb-server
wget https://raw.githubusercontent.com/daNutzzzzz/Sonos-SMB-Gateway/sonossmb.tar.gz -O /etc/node-smb-server/sonossmb.tar.gz
tar -xvf sonossmb.tar.gz
npm install

systemctl stop smbd
systemctl stop nmbd
systemctl disable smbd
systemctl disable nmbd

#open port 445 in the firewall
ufw allow 445/tcp
firewall-cmd --permanent --add-service=samba
firewall-cmd --reload
iptables -A INPUT -p tcp -m tcp --dport 445 -j ACCEPT

setcap 'cap_net_bind_service=+ep' `which node`

rm -f /etc/cron.d/sonossmb
cat >> /etc/cron.d/sonossmb << EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
* *  * * * root /usr/local/sbin/smb-pacemaker
EOF