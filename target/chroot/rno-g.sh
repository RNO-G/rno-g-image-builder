#!/bin/sh -e
#
# Copyright (c) 2014-2020 Robert Nelson <robertcnelson@gmail.com>
# Modified for RNO-G by Cosmin Deaconu <cozzyd@kicp.uchicago.edu> in 2020-2023
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

export LC_ALL=C

u_boot_release="v2019.04"
u_boot_release_x15="v2019.07-rc4"

#contains: rfs_username, release_date
if [ -f /etc/rcn-ee.conf ] ; then
	. /etc/rcn-ee.conf
fi

if [ -f /etc/oib.project ] ; then
	. /etc/oib.project
fi



export HOME=/home/${rfs_username}
export USER=${rfs_username}
export USERNAME=${rfs_username}

echo "env: [`env`]"

is_this_qemu () {
	unset warn_qemu_will_fail
	if [ -f /usr/bin/qemu-arm-static ] ; then
		warn_qemu_will_fail=1
	fi
}

qemu_warning () {
	if [ "${warn_qemu_will_fail}" ] ; then
		echo "Log: (chroot) Warning, qemu can fail here... (run on real armv7l hardware for production images)"
		echo "Log: (chroot): [${qemu_command}]"
	fi
}

git_clone () {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone ${git_repo} ${git_target_dir} --depth 1 || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} --depth 1 || true
	chown -R 1000:1000 ${git_target_dir}
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_branch () {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true"
	qemu_warning
	git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true
	chown -R 1000:1000 ${git_target_dir}
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_full () {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone --recursive ${git_repo} ${git_target_dir} || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} || true
	chown -R 1000:1000 ${git_target_dir}
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

setup_system () {
  systemctl disable bbbio-set-sysconf
  systemctl disable unattended-upgrades
  echo "#!/bin sh" > /etc/profile.d/add_sbin.sh
  echo "export PATH=\"/usr/local/sbin:/usr/sbin:/sbin:\$PATH\"" >> /etc/profile.d/add_sbin.sh
  echo spidev >> /etc/modules-load.d/modules.conf
}

#setup_desktop () {
#}


install_rno_g_software () {

  mkdir /rno-g
  mkdir /rno-g/bin
  mkdir /rno-g/cfg
  mkdir /rno-g/lib
  mkdir /rno-g/include
  mkdir /rno-g/var/
  echo 1 > /rno-g/var/runfile

  mkdir /data 

  sed -i -e "s#PATH=#PATH=/rno-g/bin:#" /etc/profile
  echo "/rno-g/lib" >> /etc/ld.so.conf.d/rno-g.conf 


  for gh_package in librno-g rno-g-ice-software rno-g-BBB-scripts control-uC radiant-python rnog-cal flowerpy rnog_gps stationrc rno-g-device-trees
  do
    cd /home/rno-g
    git_repo="https://github.com/RNO-G/$gh_package"
    git_target_dir="/home/rno-g/$gh_package" 
    git_clone_full

   
    echo "---------------------------------------------"
    echo ${gh_package} ${gh_repo} ${git_target_dir}
    echo "---------------------------------------------"
    cd ${git_target_dir} 

    if [ -f requirements.txt ] ; then 
      pip3 install --break-system-packages -r requirements.txt
    fi 

    if [ -f setup.py ] ; then 
      python3 setup.py build && python3 setup.py install 
    fi

    if [ -f Makefile ] ; then 
      if [ "$gh_package" == "librno-g" ] ;  then
         make ON_BBB=yes daq  rno-g-utils daq-test-progs  install-daq
      elif [ "$gh_package" == "control-uC" ] ; then 
        cd loader && make 
      elif [ "$gh_package" == "rno-g-ice-software" ] ; then 
        PREFIX=/rno-g make install cfg-install service-install
      elif [ "$gh_package" == "rno-g-BBB-scripts" ] ; then 
        PREFIX=/rno-g  UPDATE_INITRAMFS_ARGS=" -k ${repo_rcnee_pkg_version}" make install 
      elif [ "$gh_package" == "rno-g-device-trees" ] ; then 
        PREFIX=/rno-g  KERNEL_VERSION="${repo_rcnee_pkg_version}" make install 
      else 
        PREFIX=/rno-g make install
      fi
    fi 


    chown -R rno-g:rno-g ${git_target_dir}

  done

  chown -R rno-g:rno-g /rno-g

# sampling_rate_and_tuning branch, for now
  cd /home/rno-g
  ln -s radiant-python radpy-cal 
  cd radiant-python && git checkout sampling_rate_and_tuning && cd


#  #download swissbit lifetime monitoring tool (not anymore, it seems to have disappeared?) 
#  mkdir -p /usr/local/bin  #just in case
#  curl ftp://public:public@office.swissbit.com/SFxx_LTM_Tool/SBLTM-Linux-armv7-hard-float-1.7.0.tar.gz | tar -xz --strip-components 2 -C /usr/local/bin/ ./sbltm-linux-armv7-hard-float/sbltm-cli 


  dldir=/home/rno-g/dl 
  mkdir -p ${dldir}
  cd ${dldir} 

  chown -R rno-g:rno-g $dldir

  # bossac 1.7.0 
  curl -L https://github.com/shumatech/BOSSA/archive/refs/tags/1.7.0.tar.gz | tar xzv
  cd BOSSA-1.7.0
  make strip-bossac
  cd

  #directory for 3rd party deps 
  depsdir=/home/rno-g/deps 
  #download and install flashrom 
  mkdir -p ${depsdir}
  cd ${depsdir} 
  curl https://download.flashrom.org/releases/flashrom-v1.2.tar.bz2 | tar xjv 
  cd flashrom-v1.2 
  make && make install 

  chown -R rno-g $depsdir
  chgrp -R rno-g $depsdir

  ldconfig


}


install_git_repos () {
	if [ -f /usr/bin/make ] ; then
		echo "Installing pip packages"
		git_repo="https://github.com/adafruit/adafruit-beaglebone-io-python.git"
		git_target_dir="/opt/source/adafruit-beaglebone-io-python"
		git_clone
		if [ -f ${git_target_dir}/.git/config ] ; then
			cd ${git_target_dir}/
			sed -i -e 's:4.1.0:3.4.0:g' setup.py || true
			sed -i -e "s/strict-aliasing/strict-aliasing', '-Wno-cast-function-type', '-Wno-format-truncation', '-Wno-sizeof-pointer-memaccess', '-Wno-stringop-overflow/g" setup.py || true
			if [ -f /usr/bin/python3 ] ; then
				python3 setup.py install || true
			fi
			git reset HEAD --hard || true
		fi
	fi

	git_repo="https://github.com/strahlex/BBIOConfig.git"
	git_target_dir="/opt/source/BBIOConfig"
	git_clone

	#am335x-pru-package
	if [ -f /usr/include/prussdrv.h ] ; then
		git_repo="https://github.com/biocode3D/prufh.git"
		git_target_dir="/opt/source/prufh"
		git_clone
		if [ -f ${git_target_dir}/.git/config ] ; then
			cd ${git_target_dir}/
			if [ -f /usr/bin/make ] ; then
				make LIBDIR_APP_LOADER=/usr/lib/ INCDIR_APP_LOADER=/usr/include
			fi
			cd /
		fi
	fi


	git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
	git_target_dir="/opt/source/dtb-5.10-ti"
	git_branch="v5.10.x-ti-unified"
	git_clone_branch

	git_repo="https://github.com/beagleboard/bb.org-overlays"
	git_target_dir="/opt/source/bb.org-overlays"
	git_clone

	git_repo="https://github.com/mvduin/py-uio"
	git_target_dir="/opt/source/py-uio"
	git_clone



}

setup_git() {

if [ -f /usr/bin/git ] ; then
	git config --global user.email "cozzyd@kicp.uchicago.edu"
	git config --global user.name "Cosmin Deaconu"
	chown rno-g:rno-g /home/$USER/.gitconfig
fi
}

setup_keys() { 

for gh_user in cozzyd jakobhenrichs tikarg ejobe ryankrebs016 fschlueter barawn ; do 
ssh-import-id gh:$gh_user || true
done

chown -R rno-g:rno-g /home/$USER/.ssh
}

other_source_links () {
	rcn_https="https://rcn-ee.com/repos/git/u-boot-patches"

	mkdir -p /opt/source/u-boot_${u_boot_release}/
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release}/" ${rcn_https}/${u_boot_release}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release}/" ${rcn_https}/${u_boot_release}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release}/" ${rcn_https}/${u_boot_release}/0002-U-Boot-BeagleBone-Cape-Manager.patch
	mkdir -p /opt/source/u-boot_${u_boot_release_x15}/
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release_x15}/" ${rcn_https}/${u_boot_release_x15}/0001-am57xx_evm-fixes.patch
	rm /home/${rfs_username}/.wget-hsts || true

	echo "u-boot_${u_boot_release} : /opt/source/u-boot_${u_boot_release}" >> /opt/source/list.txt
	echo "u-boot_${u_boot_release_x15} : /opt/source/u-boot_${u_boot_release_x15}" >> /opt/source/list.txt

	chown -R ${rfs_username}:${rfs_username} /opt/source/
}

is_this_qemu

setup_system
#setup_desktop

setup_git
install_git_repos
install_rno_g_software



setup_keys

other_source_links
#
