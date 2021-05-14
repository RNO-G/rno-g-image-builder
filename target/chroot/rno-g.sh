#!/bin/sh -e
#
# Copyright (c) 2014-2020 Robert Nelson <robertcnelson@gmail.com>
# Modified for RNO-G by Cosmin Deaconu <cozzyd@kicp.uchicago.edu> in 2020 
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
	qemu_command="git clone ${git_repo} ${git_target_dir} || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} || true
	chown -R 1000:1000 ${git_target_dir}
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

setup_system () {
	#For when sed/grep/etc just gets way to complex...
	cd /
	if [ -f /opt/scripts/mods/debian-add-sbin-usr-sbin-to-default-path.diff ] ; then
		if [ -f /usr/bin/patch ] ; then
			echo "Patching: /etc/profile"
			patch -p1 < /opt/scripts/mods/debian-add-sbin-usr-sbin-to-default-path.diff
		fi
	fi

	echo "" >> /etc/securetty
	echo "#USB Gadget Serial Port" >> /etc/securetty
	echo "ttyGS0" >> /etc/securetty

	#make the sound card work by default
	if [ -f /etc/alsa/tlv320aic3104.state.txt ] ; then
		if [ -d /var/lib/alsa/ ] ; then
			cp -v /etc/alsa/tlv320aic3104.state.txt /var/lib/alsa/asound.state
			cp -v /etc/alsa/tlv320aic3104.conf.txt /etc/asound.conf
		fi
	fi
}

setup_desktop () {
	if [ -d /etc/X11/ ] ; then
		wfile="/etc/X11/xorg.conf"
		echo "Patching: ${wfile}"
		echo "Section \"Monitor\"" > ${wfile}
		echo "        Identifier      \"Builtin Default Monitor\"" >> ${wfile}
		echo "EndSection" >> ${wfile}
		echo "" >> ${wfile}
		echo "Section \"Device\"" >> ${wfile}
		echo "        Identifier      \"Builtin Default fbdev Device 0\"" >> ${wfile}
		echo "        Driver          \"fbdev\"" >> ${wfile}
		echo "#HWcursor_false        Option          \"HWcursor\"          \"false\"" >> ${wfile}
		echo "EndSection" >> ${wfile}
		echo "" >> ${wfile}
		echo "Section \"Screen\"" >> ${wfile}
		echo "        Identifier      \"Builtin Default fbdev Screen 0\"" >> ${wfile}
		echo "        Device          \"Builtin Default fbdev Device 0\"" >> ${wfile}
		echo "        Monitor         \"Builtin Default Monitor\"" >> ${wfile}
		echo "#DefaultDepth        DefaultDepth    16" >> ${wfile}
		echo "EndSection" >> ${wfile}
		echo "" >> ${wfile}
		echo "Section \"ServerLayout\"" >> ${wfile}
		echo "        Identifier      \"Builtin Default Layout\"" >> ${wfile}
		echo "        Screen          \"Builtin Default fbdev Screen 0\"" >> ${wfile}
		echo "EndSection" >> ${wfile}
	fi

	#Disable dpms mode and screen blanking
	#Better fix for missing cursor
	wfile="/home/${rfs_username}/.xsessionrc"
	echo "#!/bin/sh" > ${wfile}
	echo "" >> ${wfile}
	echo "xset -dpms" >> ${wfile}
	echo "xset s off" >> ${wfile}
	echo "xsetroot -cursor_name left_ptr" >> ${wfile}
	chown -R ${rfs_username}:${rfs_username} ${wfile}
}


install_rno_g_software () {

  mkdir /rno-g
  mkdir /rno-g/bin
  mkdir /rno-g/cfg
  mkdir /rno-g/lib
  mkdir /rno-g/include

  mkdir /data 

  sed -i -e "s#PATH=#PATH=/rno-g/bin:#" /etc/profile
  echo "/rno-g/lib" >> /etc/ld.so.conf.d/rno-g.conf 


  for gh_package in librno-g rno-g-ice-software rno-g-BBB-scripts control-uC radiant-python rnog-cal rnog_gps
  do
    git_repo="https://github.com/RNO-G/$gh_package"
    git_target_dir="/home/rno-g/$gh_package" 
    git_clone 

    cd ${git_target_dir} 

    if [ -f requirements.txt ] ; then 
      pip3 install -r requirements.txt
    fi 

    if [ -f setup.py ] ; then 
      python3 setup.py build && python3 setup.py install 
    fi

    if [ -f Makefile ] ; then 
      if [ "$gh_package" == "librno-g" ] ;  then
        make daq && PREFIX=/rno-g make install-daq
      elif [ "$gh_package" == "control-uC" ] ; then 
        cd loader && make 
      else 
        make && PREFIX=/rno-g make install 
      fi
    fi 


    chown -R rno-g ${git_target_dir}
    chgrp -R rno-g ${git_target_dir}

  done

  #download swissbit lifetime monitoring tool 
  mkdir -p /usr/local/bin  #just in case
  curl ftp://public:public@office.swissbit.com/SFxx_LTM_Tool/SBLTM-Linux-armv7-hard-float-1.7.0.tar.gz | tar -xz --strip-components 2 -C /usr/local/bin/ ./sbltm-linux-armv7-hard-float/sbltm-cli 


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
	git_target_dir="/opt/source/dtb-4.14-ti"
	git_branch="v4.14.x-ti"
	git_clone_branch

	git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
	git_target_dir="/opt/source/dtb-4.19-ti"
	git_branch="v4.19.x-ti"
	git_clone_branch

	git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
	git_target_dir="/opt/source/dtb-5.4-ti"
	git_branch="v5.4.x-ti"
	git_clone_branch

	git_repo="https://github.com/beagleboard/bb.org-overlays"
	git_target_dir="/opt/source/bb.org-overlays"
	git_clone

	if [ -f /usr/lib/librobotcontrol.so ] ; then
		git_repo="https://github.com/StrawsonDesign/librobotcontrol"
		git_target_dir="/opt/source/librobotcontrol"
		git_clone

		git_repo="https://github.com/mcdeoliveira/rcpy"
		git_target_dir="/opt/source/rcpy"
		git_clone
		if [ -f ${git_target_dir}/.git/config ] ; then
			cd ${git_target_dir}/
			if [ -f /usr/bin/python3 ] ; then
				/usr/bin/python3 setup.py install
			fi
		fi

		git_repo="https://github.com/mcdeoliveira/pyctrl"
		git_target_dir="/opt/source/pyctrl"
		git_clone
		if [ -f ${git_target_dir}/.git/config ] ; then
			cd ${git_target_dir}/
			if [ -f /usr/bin/python3 ] ; then
				/usr/bin/python3 setup.py install
			fi
		fi
	fi

	git_repo="https://github.com/mvduin/py-uio"
	git_target_dir="/opt/source/py-uio"
	git_clone



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
setup_desktop

if [ -f /usr/bin/git ] ; then
	git config --global user.email "${rfs_username}@example.com"
	git config --global user.name "${rfs_username}"
	install_git_repos
	git config --global user.email "cozzyd@kicp.uchicago.edu"
	git config --global user.name "Cosmin Deaconu"
  install_rno_g_software
	git config --global --unset-all user.email
	git config --global --unset-all user.name
	chown ${rfs_username}:${rfs_username} /home/${rfs_username}/.gitconfig
fi
other_source_links
#
