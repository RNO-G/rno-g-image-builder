#! /bin/bash 

#beware: can only create different station id's in parallel! 
station_id=0
skip_sd=0
rev=F

if [ -z "$1" ] 
then 
  echo "Usage: ./rno-g_deploy.sh /dev/sdX [station-id=0] [skip-sd=0]" 
  exit 1; 
fi

if [ -z "$2" ] 
then 
  echo "Using default station id of 0" 
else
  station_id=$2
fi

if [-z "$3" ]
then
  echo "Assuming Rev F"
else
  rev=$3
  echo "rev is $rev"
fi

if [ -z "$4" ] 
then 
  echo "Formatting SD (or image)" 
else
  skip_sd=$4
  echo "Skipping SD: $skip_sd" 
fi


echo "STATION ID is $station_id" 
hostname=`printf rno-g-%03d "$station_id"` 
echo $hostname


dev=$1 
orig_dir=`pwd` 


cd deploy/`cat latest_version` || exit 1 
prog=./setup_sdcard.sh 
args="--dtb beaglebone --enable-mainline-pru-rproc --hostname $hostname"


if [ "$skip_sd" -eq "0" ] ; 
then
#first, let's create the SD card image 
mmcarg=--mmc 
#if it doesn't start with /dev, assume mmc 
if [[ $dev == /dev/* ]] ; then 
  echo "This looks like a device" 
elif [[ $dev == *.img ]] ; then 
  echo "This looks like an image file" 
  mmcarg=--img-8gb
else 
  echo "This looks like not an image nor a device..." 
  exit 1
fi
sudo $prog $mmcarg $dev $args || exit 1 
echo "Done, waiting a few seconds just in case" 
sleep 5
fi 


#create one mount per station for parallelization
sdmountdir=sdmount-$station_id
emmcmountdir=emmcmount-$station_id

sdloopdev=none

#then, let's mount it and create the emmc flasher image on there 
sudo rm -rf $sdmountdir
sudo mkdir $sdmountdir || exit 1 
if [[ $mmcarg == "--mmc" ]] 
then 
sudo mount "${dev}"1 $sdmountdir || exit 1
else 
devname=${dev%.img}-8gb.img
sdloopdev=$(sudo losetup --show -f -P $devname) 
sudo mount "${sdloopdev}p1" $sdmountdir || exit 1
fi


#for some reason, it's actually called emmc-flash-4gb.img 
sudo $prog --img-4gb $sdmountdir/emmc-flash.img $args --bootloader $orig_dir/emmc_boot/2024/u-boot.img --spl $orig_dir/emmc_boot/2024/MLO 

sudo touch $sdmountdir/SDCARD
sudo chmod 0444 $sdmountdir/SDCARD
sudo sh -c "echo $station_id > $sdmountdir/STATION_ID"
sudo chmod 0444 $sdmountdir/STATION_ID
sudo rm -rf $emmcmountdir
sudo mkdir $emmcmountdir

loopdev=$(sudo losetup --show -f -P $sdmountdir/emmc-flash-4gb.img) 
sudo mount ${loopdev}p1 $emmcmountdir
sudo touch $emmcmountdir/INTERNAL 
sudo sh -c "echo $station_id > $emmcmountdir/STATION_ID"
sudo chmod 0444 $emmcmountdir/INTERNAL
sudo chmod 0444 $emmcmountdir/STATION_ID
sudo mkdir -p $emmcmountdir/mnt/sdcard 

sudo sh -c "echo $rev > $sdmountdir/REV"
sudo sh -c "echo $rev > $emmcmountdir/REV"

#work around wrong name for some reason: 
sudo sed -i 's/mmcblk0p1/mmcblk1p1/g' $emmcmountdir/etc/fstab
sudo sh -c "echo \"/dev/mmcblk0p1 /mnt/sdcard ext4 defaults,nofail,x-systemd.device-timeout=20 0 0 \"  >> $emmcmountdir/etc/fstab"
sudo sh -c "echo \"/mnt/sdcard/data /data none defaults,bind,nofail 0 0 \"  >> $emmcmountdir/etc/fstab"

sudo umount $emmcmountdir
sudo losetup --detach $loopdev
sudo rmdir $emmcmountdir

sudo umount $sdmountdir

if [[ "$sdloopdev" != "none" ]] ; then 
sudo losetup --detach $sdloopdev
fi

sudo rmdir $sdmountdir

cd $orig_dir


