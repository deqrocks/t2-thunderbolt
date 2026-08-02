KVER ?= $(shell uname -r)
KDIR ?= /usr/lib/modules/$(KVER)/build
PWD := $(shell pwd)
MODDIR ?= /usr/lib/modules/$(KVER)/updates
MODULE := $(MODDIR)/thunderbolt.ko
DRACUT_CONF := /etc/dracut.conf.d/90-t2-thunderbolt-test.conf
INITRAMFS := /boot/initramfs-$(KVER).img

.PHONY: all clean install uninstall

all:
	$(MAKE) -C $(KDIR) M=$(PWD)/drivers/thunderbolt modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD)/drivers/thunderbolt clean

install:
	@test "$$(id -u)" -eq 0 || { echo "make install must run as root" >&2; exit 1; }
	@test -f $(PWD)/drivers/thunderbolt/thunderbolt.ko || { echo "run make before make install" >&2; exit 1; }
	install -Dm0644 $(PWD)/drivers/thunderbolt/thunderbolt.ko $(MODULE)
	printf '%s\n' 'add_drivers+=" thunderbolt "' > $(DRACUT_CONF)
	depmod -a $(KVER)
	@test "$$(readlink -f "$$(modinfo -k $(KVER) -n thunderbolt)")" = "$$(readlink -f $(MODULE))" || { echo "installed thunderbolt module is not preferred by modprobe" >&2; exit 1; }
	dracut --force $(INITRAMFS) $(KVER)
	@lsinitrd $(INITRAMFS) | grep -Fq 'usr/lib/modules/$(KVER)/updates/thunderbolt.ko' || { echo "thunderbolt.ko is missing from $(INITRAMFS)" >&2; exit 1; }

uninstall:
	@test "$$(id -u)" -eq 0 || { echo "make uninstall must run as root" >&2; exit 1; }
	rm -f $(MODULE) $(DRACUT_CONF)
	depmod -a $(KVER)
	dracut --force $(INITRAMFS) $(KVER)
	@if lsinitrd $(INITRAMFS) | grep -Fq 'usr/lib/modules/$(KVER)/updates/thunderbolt.ko'; then \
		echo "test thunderbolt.ko is still present in $(INITRAMFS)" >&2; \
		exit 1; \
	fi
