#! /bin/sh 

#beware: can only create different station id's in parallel! 
station_id=0

if [ -z "$1" ] 
then 
  echo "Usage: ./rno-g_deploy.sh /dev/sdX [station-id=0]" 
  exit 1; 
fi

if [ -z "$2" ] 
then 
  station_id=$2
fi

echo "STATION ID is $station_id" 
hostname=`printf rno-g-%03d "$station_id"` 

dev=$1 
orig_dir=`pwd` 


cd deploy/`cat latest_version` || exit 1 
prog=./setup_sdcard.sh 
args="--dtb beaglebone --hostname $hostname"

#first, let's create the SD card image 
sudo $prog --mmc $dev $args || exit 1 

#create one mount per station for parallelization
sdmountdir=sdmount-$station_id
emmcmountdir=emmcmount-$station_id

#then, let's mount it and create the emmc flasher image on there 
sudo rm -rf $sdmountdir
sudo mkdir $sdmountdir
sudo mount "${dev}"1 $sdmountdir

#for some reason, it's actually called emmc-flash-4gb.img 
sudo $prog --img-4gb $sdmountdir/emmc-flash.img $args --bootloader $orig_dir/emmc_boot/u-boot.img --spl $orig_dir/emmc_boot/MLO 
sudo touch $sdmountdir/SDCARD
sudo chmod 0444 $sdmountdir/SDCARD
sudo echo $station_id > $sdmountdir/STATION_ID
sudo chmod 0444 $sdmountdir/STATION_ID
sudo rm -rf $emmcmountdir
sudo mkdir $emmcmountdir

loopdev=$(sudo losetup --show -f -P $sdmountdir/emmc-flash-4gb.img) 
sudo mount ${loopdev}p1 $emmcmountdir
sudo touch $emmcmountdir/INTERNAL 
sudo echo $station_id > $emmcmountdir/STATION_ID
sudo chmod 0444 $emmcmountdir/INTERNAL
sudo chmod 0444 $emmcmountdir/STATION_ID
sudo mkdir -p $emmcmountdir/mnt/sdcard 
sudo echo "/dev/mmcblk0p1 /mnt/sdcard ext4 defaults 0 0 "  >> $emmcmountdir/etc/fstab
sudo echo "/mnt/sdcard/data /data none defaults,bind 0 0 "  >> $emmcmountdir/etc/fstab

sudo umount $emmcmountdir
sudo losetup --detach $loopdev
sudo rmdir $emmcmountdir

sudo umount $sdmountdir
sudo rmdir $sdmountdir

cd $orig_dir


