################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

DEBUG ?= 0

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/spl/sunxi-spl.bin

################################################################################
# Targets
################################################################################
all: arm-tf u-boot linux optee-os buildroot
clean: arm-tf-clean buildroot-clean u-boot-clean optee-os-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	PLAT=sun50iw1p1 \
	SPD=opteed

arm-tf: optee-os u-boot
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Das U-Boot
################################################################################

U-BOOT_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

U-BOOT_DEFCONFIG_FILES := \
	$(U-BOOT_PATH)/configs/nanopi_h5_defconfig \
	$(ROOT)/build/kconfigs/u-boot_nano.conf

.PHONY: u-boot
u-boot:
	cd $(U-BOOT_PATH) && \
		scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_FILES)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all

u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/nanopi_h5_defconfig \
		$(CURDIR)/kconfigs/nano.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=sunxi-sun50i_h5
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=sunxi-sun50i_h5
optee-os-clean: optee-os-clean-common


$(ROOT)/out-br/images/ramdisk.img: $(ROOT)/out-br/images/rootfs.cpio.gz
	$(U-BOOT_PATH)/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip \
		-d $< $@

FTP-UPLOAD = ftp-upload -v --host $(nano_IP) --dir SOFTWARE

.PHONY: flash
flash: $(ROOT)/out-br/images/ramdisk.img
	@test -n "$(nano_IP)" || \
		(echo "nano_IP not set" ; exit 1)
	$(FTP-UPLOAD) $(ROOT)/vexpress-firmware/SOFTWARE/scp_bl1.bin
	$(FTP-UPLOAD) $(ARM_TF_PATH)/build/nano/release/bl1.bin
	$(FTP-UPLOAD) $(ARM_TF_PATH)/build/nano/release/fip.bin
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/Image
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/arm/nano.dtb
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/arm/nano-r1.dtb
	$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/arm/nano-r2.dtb
	$(FTP-UPLOAD) $(ROOT)/out-br/images/ramdisk.img
