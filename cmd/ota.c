
// SPDX-License-Identifier: GPL-2.0+
/*
 * (C) Copyright 2011 - 2012 Samsung Electronics
 * EXT4 filesystem implementation in Uboot by
 * Uma Shankar <uma.shankar@samsung.com>
 * Manjunatha C Achar <a.manjunatha@samsung.com>
 *
 * Ext4fs support
 * made from existing cmd_ext2.c file of Uboot
 *
 * (C) Copyright 2004
 * esd gmbh <www.esd-electronics.com>
 * Reinhard Arlt <reinhard.arlt@esd-electronics.com>
 *
 * made from cmd_reiserfs by
 *
 * (C) Copyright 2003 - 2004
 * Sysgo Real-Time Solutions, AG <www.elinos.com>
 * Pavel Bartusek <pba@sysgo.com>
 */

/*
 * Changelog:
 *	0.1 - Newly created file for ext4fs support. Taken from cmd_ext2.c
 *	        file in uboot. Added ext4fs ls load and write support.
 */

#include <common.h>
#include <part.h>
#include <config.h>
#include <command.h>
#include <image.h>
#include <linux/ctype.h>
#include <asm/byteorder.h>
#include <linux/stat.h>
#include <malloc.h>
#include <fs.h>
#include <ota.h>

int do_ota_write(cmd_tbl_t *cmdtp, int flag, int argc,
						char *const argv[])
{
	return ota_write(cmdtp, flag, argc, argv);
}

U_BOOT_CMD(otawrite, 5, 0, do_ota_write,
	   "write binary file to gpt partiton",
	   "<partition name> <ddr addr> <image size> [emmc|nor] \n"
	   "    - emmc partition name: \n"
	   "           [all | gpt-main | sbl | ddr | uboot | kernel | system | app | gpt-backup]\n"
	   "    - nor partition name: \n"
	   "           [all | uboot | kernel | system | app]\n"
	   "    - image size: \n"
	   "           bytes size  [Example: 0x8000]\n"
	   "    - emmc|nor: \n"
	   "          options, write emmc or nor partition\n"
	   "          default: writing device depend on bootmode\n"
	   "    - example:\n"
	   "          otawrite uboot 0x4000000 0x100000\n"
);
