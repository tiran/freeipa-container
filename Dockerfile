# Clone from the RHEL 6
# FROM rhel6
# Workaround 1205054 and possibly 1182662
FROM rhel6.5
RUN yum upgrade -y && yum clean all

MAINTAINER Jan Pazdziora

# Install FreeIPA server
RUN yum install -y ipa-server bind bind-dyndb-ldap perl && yum clean all

# We start dbus directly as dbus user, to avoid dropping capabilities
# which does not work in unprivileged container.
RUN sed -i 's/daemon --check/daemon --user "dbus -g root" --check/' /etc/init.d/messagebus

ADD ipa-server-configure-first /usr/sbin/ipa-server-configure-first

RUN chmod -v +x /usr/sbin/ipa-server-configure-first

RUN groupadd -g 389 dirsrv ; useradd -u 389 -g 389 -c 'DS System User' -d '/var/lib/dirsrv' --no-create-home -s '/sbin/nologin' dirsrv
RUN groupadd -g 17 pkiuser ; useradd -u 17 -g 17 -c 'CA System User' -d '/var/lib' --no-create-home -s '/sbin/nologin' pkiuser
RUN useradd -u 388 -g 389 -c 'PKI DS System User' -d '/var/lib/dirsrv' --no-create-home -s '/sbin/nologin' pkisrv
RUN mkdir -p /var/run/dirsrv ; chown pkisrv:dirsrv /var/run/dirsrv ; chmod 770 /var/run/dirsrv

ADD volume-data-list /etc/volume-data-list
ADD volume-data-mv-list /etc/volume-data-mv-list
RUN cd / ; mkdir /data-template ; cat /etc/volume-data-list | while read i ; do if [ -e $i ] ; then tar cf - .$i | ( cd /data-template && tar xf - ) ; fi ; mkdir -p $( dirname $i ) ; rm -rf $i ; ln -sf /data${i%/} ${i%/} ; done
RUN mv /data-template/etc/dirsrv/schema /usr/share/dirsrv/schema && ln -s /usr/share/dirsrv/schema /data-template/etc/dirsrv/schema
RUN echo 0.5 > /etc/volume-version
RUN uuidgen > /data-template/build-id

EXPOSE 53/udp 53 80 443 389 636 88 464 88/udp 464/udp 123/udp 7389 9443 9444 9445

VOLUME /data

ENTRYPOINT /usr/sbin/ipa-server-configure-first
