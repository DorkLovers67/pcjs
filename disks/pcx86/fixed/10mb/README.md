---
layout: page
title: 10Mb Hard Drive (Fixed Disk) Images
permalink: /disks/pcx86/fixed/10mb/
---

10Mb Hard Drive (Fixed Disk) Images
-----------------------------------

This folder contains the following 10Mb fixed disk images:
 
* [Empty formatted disk](PCDOS200-EMPTY.json) ([XML](pcdos200-empty.xml))
* [PC-DOS 2.00 with Windows 1.01 for CGA](PCDOS200-WIN101-CGA.json) ([XML](pcdos200-win101-cga.xml))
* [PC-DOS 2.00 with Windows 1.01 for EGA](PCDOS200-WIN101-EGA.json) ([XML](pcdos200-win101-ega.xml))

These disk images are used by various IBM PC XT [Model 5160](/devices/pcx86/machine/5160/) machine configurations,
either directly:

```xml
<hdc id="hdcXT" drives='[{name:"10Mb Hard Drive",path:"/disks/pcx86/fixed/10mb/PCDOS200-WIN101-CGA.json",type:3}]'/>
```

or by reference:

```xml
<hdc ref="/disks/pcx86/fixed/10mb/pcdos200-win101-cga.xml"/>
```

### Notes Regarding 10Mb Disks

The [Empty formatted disk](PCDOS200-EMPTY.json) is *completely* empty.  It was partitioned with the PC-DOS 2.00
**FDISK** utility, allocating the entire disk to a single DOS partition, and then it was formatted with the PC-DOS 2.00
**FORMAT** utility.  Neither the **FORMAT** "/S" option nor the **SYS** command were used, so no system files were
transferred, leaving the disk completely empty and non-bootable.

After formatting, PC-DOS 2.00 reports:

	10592256 bytes total disk space
	10592256 bytes available on disk

As explained in the [DiskDump source code](/modules/diskdump/lib/diskdump.js), in its description of the 10Mb
BPB, a 10Mb "Type 3" PC XT fixed disk contains:

	306 cylinders
	4 heads
	17 sectors/track

for a total of 20808 sectors or 10,653,696 bytes.  However, as p.1-179 of the PC XT Technical Reference Manual
(April 1983) notes:

	WARNING: The last cylinder on the fixed disk drive is reserved for diagnostic use.
    Diagnostic write tests will destroy any data on this cylinder.

And this is confirmed by the PC XT BIOS, p.A-94, in the code for the "GET PARAMETERS (AH = 8)" function:

	C800:03B2 268B07        MOV     AX,ES:[BX]      ; MAX NUMBER OF CYLINDERS
	C800:03B5 2D0200        SUB     AX,2            ; ADJUST FOR 0-N AND RESERVE LAST TRACK

By "RESERVE LAST TRACK", they really meant "RESERVE LAST CYLINDER", because 68 (not 17) sectors are reserved at
the end of the disk.  In addition, the first sector of the disk is reserved for the Master Boot Record (MBR), so there
are a total of 69 reserved sectors.  (20808 - 69) = 20739 or 0x5103, which is exactly what's stored in the "total
sectors" field of the disk's BPB, yielding a total partition size of 10,618,368 bytes.

However, that 69-sector overhead is not the end of the story.  There is also overhead incurred by the FAT file system,
which, in this case, consists of:

- Boot sector (1)
- FAT sectors (2 * 8 = 16)
- Root directory sectors (32)

for a total of 49 sectors, leaving (20739 - 49) = 20690 sectors.  Moreover, free space is measured in clusters,
not sectors, and the partition uses 8 sectors/cluster, leaving room for 2586.25 clusters.  Since a fractional cluster
is not allowed, another 2 sectors are lost, bringing the total FAT file system overhead to 51 sectors.
 
Thus, actual free space is (20739 - 51) * 512, or 10,592,256 bytes, which is exactly what DOS reports as the available
space.

Some sources on the internet (eg,[http://www.wikiwand.com/en/Timeline_of_DOS_operating_systems](http://www.wikiwand.com/en/Timeline_of_DOS_operating_systems))
claim that the FAT file system overhead for the XT's 10Mb disk is "50 sectors".  As they explain:

	"The fixed disk has 10,618,880 bytes of raw space: 305 cylinders (the equivalent of tracks) × 2 platters
	× 2 sides or heads per platter × 17 sectors per track = 20,740 sectors × 512 bytes per sector = 10,618,880
	bytes...."

and:

	"With DOS the only partition, the combined overhead is 50 sectors leaving 10,592,256 bytes for user data:
	DOS's FAT is eight sectors (16 sectors for two copies) + 32 sectors for the root directory, room for 512
	directory entries + 2 sectors (one master and one DOS boot sector) = 50 sectors...."

However, that's incorrect.  First, the disk has 306 cylinders, not 305.  Second, there are TWO overhead values:
the overhead OUTSIDE the partition (69 sectors) and the overhead INSIDE the partition (51 sectors).  They failed
to account for the reserved cylinder in the first calculation and the lost fractional cluster in the second
calculation, and then they conflated the two values to produce a single (incorrect) result.
