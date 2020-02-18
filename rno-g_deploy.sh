#! /bin/sh 

station_id=0

if [ -z "$1" ] 
then 
  echo "Usage: ./rno-g_deploy.sh /dev/sdX station-id=0" 
  exit 1; 
fi

if [ -z "$2" ] 
then 
  station_id=$2
fi

hostname=`printf rno-g-%03d "$station_id"` 

dev=$1 
orig_dir=`pwd` 


cd deploy/`cat latest_version` || exit 1 
prog=./setup_sdcard.sh 
args="--dtb beaglebone --hostname=$hostname"

#first, let's create the SD card image 
sudo $prog --mmc $dev $args || exit 1 

#then, let's mount it and create the emmc flasher image on there 
sudo mkdir sdmount
sudo mount "${dev}"1 sdmount 

sudo $prog --img-4gb sdmount/emmc-flash.img $args --bootloader $orig_dir/emmc_boot/u-boot.img --spl $orig_dir/emmc_boot/MLO 
sudo touch sdmount/home/rno-g/SD_CARD


sudo umount sdmount
sudo rmdir sdmount

cd $orig_dir


