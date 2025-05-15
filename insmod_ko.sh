#!/bin/sh
KERNEL_VERSION=`uname -r`
MODULES_PREFIX="/lib/modules"
MODULES_PATH="$MODULES_PREFIX/$KERNEL_VERSION"
CMD=`realpath $0`
DIR=`dirname $CMD`

if [ ! -d $MODULES_PATH ]; then
	mkdir -p $MODULES_PREFIX
	ln -s $DIR $MODULES_PATH
	depmod -a > /dev/null 2>&1
	return 0
else
	depmod -a > /dev/null 2>&1
	return 0
fi

udevadm control --stop-exec-queue

echo 1 > /sys/module/video_rkcif/parameters/clr_unready_dev
echo 1 > /sys/module/video_rkisp/parameters/clr_unready_dev

# rmmod non-exist camera driver
for drv_name in `ls /sys/devices/platform/ff470000.i2c/i2c-4/4*/name`; do
	dir=`dirname $drv_name`
	if [ ! -L $dir/driver ]; then
		rmmod `cat $drv_name`
	fi
done

# rv1103 unsupport 5M
grep -q "rockchip,rv1103" /proc/device-tree/compatible
if [ $? == 0 ]; then
	rmmod sc530ai
fi

sensor_height=0
lsmod | grep sc530ai
if [ $? -eq 0 ] ;then
    sensor_height=1616
fi
lsmod | grep sc4336
if [ $? -eq 0 ] ;then
    sensor_height=1440
fi
lsmod | grep sc3336
if [ $? -eq 0 ] ;then
    sensor_height=1296
fi

modprobe rockit mcu_fw_path="$MODULES_PATH/hpmcu_wrap.bin" mcu_fw_addr=0xff6ff000 isp_max_h=$sensor_height
modprobe wireguard

udevadm control --start-exec-queue
