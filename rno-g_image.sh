#! /bin/sh 

# ./rno-g_image.sh 

if [ -z "$RNO_G_PASSWORD" ] 
then
  echo Please define \$RNO_G_PASSWORD 
  exit 1;
fi 

HOSTNAME_SUFFIX=${1}
sed -e "s/#PLACEHOLDER_PASSWORD#/$RNO_G_PASSWORD/" configs/rno-g.conf > configs/rno-g.tmp.conf

sudo ./RootStock-NG.sh -c rno-g.tmp.conf || exit 1 
rm configs/rno-g.tmp.conf


echo "Image created. Use rno-g_deploy.sh to deploy." 

