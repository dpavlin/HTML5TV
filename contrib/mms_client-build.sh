#wget -nc http://web.archive.org/web/20071011022352/http://geocities.com/majormms/xine-mms-0.0.3.tar.gz
wget -nc http://web.archive.org/web/20071011022352/http://geocities.com/majormms/mms_client-0.0.3.tar.gz

tar xvfz mms_client-*.tar.gz

cd mms_client-* && ./configure && make
