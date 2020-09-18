#!/bin/bash

function choose()
{
    local tmp="$cur_dir/include/configs/.hb_config.h"
    local target="$cur_dir/include/configs/hb_config.h"
    local conftmp="$cur_dir/.config_tmp"
    local line=`sed -n '/system/p; /system/q' ${GPT_CONFIG}`
    local arr=(${line//:/ })
    local fs_type=${arr[2]}
    echo "*********************************************************************"
    echo "boot mode= $bootmode"
    echo "*********************************************************************"
    cp $cur_dir/.config $conftmp

    echo "#ifndef __HB_CONFIG_H__" > $tmp
    echo "#define __HB_CONFIG_H__" >> $tmp

    if [ "$bootmode" = "nor" ];then
        echo "/* #define CONFIG_HB_NAND_BOOT */" >> $tmp
        echo "#define CONFIG_HB_NOR_BOOT" >> $tmp
        echo "/* #define CONFIG_HB_MMC_BOOT */" >> $tmp
        sed -i "/CONFIG_SPL_YMODEM_SUPPORT/d" $conftmp
        echo "CONFIG_SPL_YMODEM_SUPPORT=n" >> $conftmp
    elif [ "$bootmode" = "nand" ];then
        echo "#define CONFIG_HB_NAND_BOOT" >> $tmp
        echo "/* #define CONFIG_HB_NOR_BOOT */" >> $tmp
        echo "/* #define CONFIG_HB_MMC_BOOT */" >> $tmp
        echo "#define NAND_PAGE_SIZE ${PAGE_SIZE}" >> $tmp
        sed -i "/CONFIG_SPL_YMODEM_SUPPORT/d" $conftmp
        echo "CONFIG_SPL_YMODEM_SUPPORT=n" >> $conftmp
    elif [ "$bootmode" = "emmc" ];then
        echo "/* #define CONFIG_HB_NAND_BOOT */" >> $tmp
        echo "/* #define CONFIG_HB_NOR_BOOT */" >> $tmp
        echo "#define CONFIG_HB_MMC_BOOT" >> $tmp
        sed -i "/CONFIG_SPL_YMODEM_SUPPORT/d" $conftmp
        echo "CONFIG_SPL_YMODEM_SUPPORT=n" >> $conftmp
    else
        echo "Unknown BOOT_MODE value: $bootmode"
        exit 1
    fi
    if ! inList "$fs_type" "ext4 squashfs" ;then
        echo "#define ROOTFS_TYPE \"ext4\"" >> $tmp
    else
        echo "#define ROOTFS_TYPE \"$fs_type\"" >> $tmp
    fi
    echo "#endif /* __HB_CONFIG_H__ */" >> $tmp

    mv $tmp $target
    mv $conftmp .config
}

function change_dts_flash_config()
{
    local dts_file="$cur_dir/arch/arm/dts/hobot-x3-soc.dts"
    local key_value="qspi {"

    declare -i nline

    getline()
    {
        cat -n $dts_file|grep "${key_value}"|awk '{print $1}'
    }

    getlinenum()
    {
        awk "BEGIN{a=`getline`;b="1";c=(a+b);print c}";
    }

    nline=`getlinenum`

    if [ x"$bootmode" = x"nor" ] || [ x"$bootmode" = x"nand" ] \
       || [ ! -z "$FLASH_ENABLE" ];then
        sed -i "${nline}s#disabled#okay#g" $dts_file
    else
        sed -i "${nline}s#okay#disabled#g" $dts_file
    fi
}

function build()
{
    # config dts
    # change_dts_flash_config

    set_uboot_config

    local uboot_image="u-boot.bin"
    prefix=$TARGET_UBOOT_DIR
    config=$UBOOT_DEFCONFIG
    echo "uboot config: $config"

    if [ x"$OPTIMIZE_BOOT_LOG" = x"true" ];then
        OPTIMIZE_LOG="-DUBOOT_LOG_OPTIMIZE"
    fi

    # real build
    ARCH=$ARCH_KERNEL
    make $config || {
        echo "make $config failed"
        exit 1
    }

    choose

    make KCFLAGS="$OPTIMIZE_LOG" -j${N} || {
        echo "make failed"
        exit 1
    }

    # put binaries to dest directory
    if [ x"$OPTIMIZE_BOOT_LOG" = x"true" ];then
        cp -rf $uboot_image $prefix/u-boot-optimize.bin
        if [ ! -f $prefix/$uboot_image ];then
            cpfiles "$uboot_image" "$prefix/"
        fi
    else
        cpfiles "$uboot_image" "$prefix/"
    fi

    if [ "$pack_img" = "true" ];then
        if [ -d "$prefix/" ];then
            # encrypt and sign uboot image
            path="$SRC_BUILD_DIR/tools/key_management_toolkits"
            cd $path
            bash pack_uboot_tool.sh || {
                echo "$SRC_BUILD_DIR/tools/key_management_toolkits/pack_uboot_tool.sh failed"
                exit 1
            }
            cd -
        fi
        runcmd "dd if=/dev/zero of=$TARGET_DEPLOY_DIR/uboot.img bs=512 count=4096 conv=notrunc,sync"
        runcmd "dd if=$TARGET_DEPLOY_DIR/uboot/$UBOOT_IMAGE_NAME of=$TARGET_DEPLOY_DIR/uboot.img conv=notrunc,sync"
        runcmd "dd if=$TARGET_DEPLOY_DIR/uboot/$UBOOT_IMAGE_NAME of=$TARGET_DEPLOY_DIR/uboot.img bs=512 seek=2048 conv=notrunc,sync"
    fi
}

function all()
{
    build
}

function all_32()
{
    CROSS_COMPILE=$CROSS_COMPILE_64
    all
}

function set_uboot_config()
{
    # Defaults
    sed -i 's/# CONFIG_CMD_MTDPARTS is not set/CONFIG_CMD_MTDPARTS=y/g' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i '/CONFIG_MTDIDS_DEFAULT/d' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i '/CONFIG_MTDPARTS_DEFAULT/d' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i 's/CONFIG_ENV_IS_IN_UBI=y/# CONFIG_ENV_IS_IN_UBI is not set/g' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i 's/CONFIG_ENV_IS_IN_SPI_FLASH=y/# CONFIG_ENV_IS_IN_SPI_FLASH is not set/g' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i 's/# CONFIG_ENV_IS_IN_MMC is not set/CONFIG_ENV_IS_IN_MMC=y/g' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i 's/CONFIG_MTD_UBI_FASTMAP=y/# CONFIG_MTD_UBI_FASTMAP is not set/g' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i 's/CONFIG_MTD_UBI_FASTMAP_AUTOCONVERT=1/# CONFIG_MTD_UBI_FASTMAP_AUTOCONVERT is not set/g' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i '/CONFIG_CMD_MTDPARTS/a CONFIG_MTDIDS_DEFAULT=""'  $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i '/CONFIG_MTDIDS_DEFAULT/a CONFIG_MTDPARTS_DEFAULT=""' $cur_dir/configs/$UBOOT_DEFCONFIG
    sed -i 's/# CONFIG_SPI_FLASH_MTD is not set/CONFIG_SPI_FLASH_MTD=y/g' $cur_dir/configs/$UBOOT_DEFCONFIG

    if [[ "$bootmode" = "nand" ]] || [[ "$FLASH_ENABLE" = "nand" ]];then
        sed -i 's/# CONFIG_MTD_UBI_FASTMAP is not set/CONFIG_MTD_UBI_FASTMAP=y/g' $cur_dir/configs/$UBOOT_DEFCONFIG
        sed -i 's/# CONFIG_MTD_UBI_FASTMAP_AUTOCONVERT is not set/CONFIG_MTD_UBI_FASTMAP_AUTOCONVERT=1/g' $cur_dir/configs/$UBOOT_DEFCONFIG
        if [[ "$bootmode" = "nand" ]];then
            sed -i 's/CONFIG_ENV_IS_IN_MMC=y/# CONFIG_ENV_IS_IN_MMC is not set/g' $cur_dir/configs/$UBOOT_DEFCONFIG
            sed -i 's/# CONFIG_ENV_IS_IN_UBI is not set/CONFIG_ENV_IS_IN_UBI=y/g' $cur_dir/configs/$UBOOT_DEFCONFIG
        fi
        sed -i 's/CONFIG_MTDIDS_DEFAULT=""/CONFIG_MTDIDS_DEFAULT="spi-nand0=hr_nand.0"/g'  $cur_dir/configs/$UBOOT_DEFCONFIG
        # TODO: change to read from conf and generate automatically
        if [[ "$PAGE_SIZE" = "4096" ]];then
            sed -i 's/CONFIG_MTDPARTS_DEFAULT=""/CONFIG_MTDPARTS_DEFAULT="mtdparts=hr_nand.0:9699328@0x0(bootloader),22544384@0x940000(boot),62914560@0x1EC0000(rootfs),-@0x5AC0000(userdata)"/g' $cur_dir/configs/$UBOOT_DEFCONFIG
        else
            sed -i 's/CONFIG_MTDPARTS_DEFAULT=""/CONFIG_MTDPARTS_DEFAULT="mtdparts=hr_nand.0:9568256@0x0(bootloader),22544384@0x920000(boot),62914560@0x1EA0000(rootfs),-@0x5AA0000(userdata)"/g' $cur_dir/configs/$UBOOT_DEFCONFIG
        fi
    elif [[ "$bootmode" = "nor" ]] || [[ "$FLASH_ENABLE" = "nor" ]];then
        if [[ "$bootmode" = "nor" ]];then
            sed -i 's/CONFIG_ENV_IS_IN_MMC=y/# CONFIG_ENV_IS_IN_MMC is not set/g' $cur_dir/configs/$UBOOT_DEFCONFIG
            sed -i 's/# CONFIG_ENV_IS_IN_SPI_FLASH is not set/CONFIG_ENV_IS_IN_SPI_FLASH=y/g' $cur_dir/configs/$UBOOT_DEFCONFIG
        fi
        sed -i 's/CONFIG_MTDIDS_DEFAULT=""/CONFIG_MTDIDS_DEFAULT="spi-nor1=hr_nor.0"/g'  $cur_dir/configs/$UBOOT_DEFCONFIG
        sed -i 's/CONFIG_MTDPARTS_DEFAULT=""/CONFIG_MTDPARTS_DEFAULT="mtdparts=hr_nor.0:655360@0x20000(sbl),524288@0xA0000(ddr),393216@0x120000(bl31),2097152@0x180000(uboot),131072@0x380000(bpu),131072@0x3A0000(vbmeta),10485760@0x3C0000(boot),34603008@0xDC0000(system),-@0x2EC0000(app)"/g' $cur_dir/configs/$UBOOT_DEFCONFIG
    fi
}

function usage()
{
    echo "Usage: build.sh [-o emmc|nor|nand|all ] [-u] [-p] [-l]"    echo "Options:"
    echo "Options:"
    echo "  -o  boot mode, all or one of uart, emmc, nor, nand, ap"
    echo "  -p  create uboot.img"
    echo "  -l  gets the minimum boot log image"
    echo "  -h  help info"
    echo "Command:"
    echo "  clean clean all the object files along with the executable"
}

bootmode=$BOOT_MODE
pack_img="false"
while getopts "upo:lh:" opt
do
    case $opt in
        o)
            arg="$OPTARG"
            if [ "$arg" = "all" ];then
                all_boot_mode=true
                echo "compile all boot mode"
            else
                export bootmode="$OPTARG"
                echo "compile boot mode $bootmode"
            fi
            ;;

        p)
            pack_img="true"
            ;;
        l)
            OPTIMIZE_BOOT_LOG="true"
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
done

shift $[ $OPTIND - 1 ]

cmd=$1

function clean()
{
    make clean
}

# include
. $INCLUDE_FUNCS
# include end
cur_dir=${OUT_BUILD_DIR}/uboot

cd $(dirname $0)

buildopt $cmd
