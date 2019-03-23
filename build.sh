#!/bin/sh

config=$UBOOT_DEFCONFIG
echo "uboot config: $config"

cd $(dirname "$0";pwd)
ARCH=$ARCH_UBOOT
make $config || {
    echo "make $config failed"
    exit 1
}
make -j${N}

if [ -f $SRC_UBOOT_DIR/$SRC_UBOOT_IMAGE_NAME -a -n $TARGET_UBOOT_DIR/$TARGET_UBOOT_IMAGE_NAME ];then
    mkdir -p $TARGET_UBOOT_DIR
    echo "cp -f $SRC_UBOOT_DIR/$SRC_UBOOT_IMAGE_NAME $TARGET_UBOOT_DIR/$TARGET_UBOOT_IMAGE_NAME"
    cp -f $SRC_UBOOT_DIR/$SRC_UBOOT_IMAGE_NAME $TARGET_UBOOT_DIR/$TARGET_UBOOT_IMAGE_NAME
fi
if [ -f $SRC_UBOOT_DIR/spl/$SRC_UBOOT_SPL_NAME -a -n $TARGET_UBOOT_DIR/$TARGET_UBOOT_SPL_NAME ];then
    mkdir -p $TARGET_UBOOT_DIR
    echo "cp -f $SRC_UBOOT_DIR/spl/$SRC_UBOOT_SPL_NAME $TARGET_UBOOT_DIR/$TARGET_UBOOT_SPL_NAME"
    cp -f $SRC_UBOOT_DIR/spl/$SRC_UBOOT_SPL_NAME $TARGET_UBOOT_DIR/$TARGET_UBOOT_SPL_NAME
fi
