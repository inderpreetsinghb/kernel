
# shell variables
block=/dev/block/platform/soc.0/7824900.sdhci/by-name/boot;

## end setup


## AnyKernel methods (DO NOT CHANGE)
# set up extracted files and directories
project=/tmp/anykernel/project_o/*;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;
kernel=/tmp/anykernel/zImage;
dtb=/tmp/anykernel/dt_o/dt.img;
modules=/tmp/anykernel/modules/*
prop=$(grep "ro.build.version.sdk" /system/build.prop | cut -d'=' -f2 );

# Checking for Oreo
if [ $prop -lt 27 ]; then
dtb=/tmp/anykernel/dt_n/dt.img;
project=/tmp/anykernel/project_n/*;
else
if [[ ! -f "/system/vendor/etc/fstab.qcom" ]]; then
project=/tmp/anykernel/project_o/*;
fi
dtb=/tmp/anykernel/dt_o/dt.img;
fi

chmod -R 755 $bin;
mkdir $split_img;
ramdisk=/tmp/anykernel/split_img/ramdisk;

# dump boot and extract ramdisk
dump_boot() {
  dd if=$block of=/tmp/anykernel/boot.img;
  $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Dumping/unpacking image failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode; exit;
  fi;
}

ramdisk() {
  mkdir $ramdisk;
  cd $ramdisk;
  gzip -dc ../boot.img-ramdisk.gz | cpio -i;
  rm -rf ../boot.img-ramdisk.gz;
  if [[ ! -f "/system/vendor/etc/fstab.qcom" ]]; then
   cp $project $ramdisk;
  else
   if [[ ! -f "/system/vendor/etc/init/hw/init.qcom.power.rc" ]]; then 
    cp /tmp/anykernel/ramdisk/*.rc $ramdisk;
   else
    cp /tmp/anykernel/ramdisk/*.rc /system/vendor/etc/init/hw/;
   fi
  fi
  find . | cpio -o -H newc | gzip > ../boot.img-ramdisk.gz
  ui_print "Ramdisk Fixing Done";

}


# repack ramdisk then build and write image
write_boot() {
  cd $split_img;
  cmdline=`cat *-cmdline`;
  board=`cat *-board`;
  base=`cat *-base`;
  pagesize=`cat *-pagesize`;
  kerneloff=`cat *-kerneloff`;
  ramdiskoff=`cat *-ramdiskoff`;
  tagsoff=`cat *-tagsoff`;
  if [ -f *-second ]; then
    second=`ls *-second`;
    second="--second $split_img/$second";
    secondoff=`cat *-secondoff`;
    secondoff="--second_offset $secondoff";
  fi;
  $bin/mkbootimg --kernel $kernel --ramdisk /tmp/anykernel/split_img/boot.img-ramdisk.gz $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff --dt $dtb --output /tmp/anykernel/boot-new.img;
  if [ $? != 0 -o `wc -c < /tmp/anykernel/boot-new.img` -gt `wc -c < /tmp/anykernel/boot.img` ]; then
    ui_print " "; ui_print "Repacking image failed. Aborting...";
    echo 1 > /tmp/anykernel/exitcode; exit;
  fi;
  dd if=/tmp/anykernel/boot-new.img of=$block;
}

dump_boot;

ramdisk;

write_boot;

## end install

