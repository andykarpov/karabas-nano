esxDOS v0.8.7
(c) 2005-2019 Papaya Dezign
---------------------------

This version has the following (notable) new features (for detailed info checkout the changelog):

* Experimental Z80 DMA (Z8410) I/O support (enabled in ESXDOS.CFG - please test and report)
* New "utime" syscall
* New/Updated Commands: .dfwload, .more, .dumpmem and .sercp

How to (safely) install/upgrade:
--------------------------------

1. Copy esxide.tap/esxmmc.tap/mb03plus.tap (depending on if you have a DivIDE, DivMMC or MB03+, obviously) to your CF/SD/HDD, load it and follow the instructions. Power Off and remove media.
2. Copy the SYS, BIN (and create /TMP if using DivIDE) directories to your CF/SD/HDD.
3. Insert media. Power On. Reset while keeping space pressed to reinit if needed.

Notes:
------

a) If you replace the SYS directory *before* flashing the new ROM, your previous ROM of esxDOS will not boot correctly.
b) Questions? Bugreports? Complaints about lack of LFN/instructions? Ask on the usual places or send an e-mail to: bugs at esxdos dot org

Changelog
---------

[24/05/2018] FAT Driver: Fixed a bug that prevented writing the EEPROM to disk (lordcoxis + reported by ub880d)
[30/06/2018] Commands: Added .dfwload (ub880d)
[03/11/2018] NMI: Slightly changed keyboard routine to reduce key bounce on unreliable keyboards (ub880d)
[19/01/2019] FAT Driver: Fixed a critical bug (introduced in v0.8.6) when creating directory entries on DivMMC (lordcoxis + reported by Ben Versteeg)
[19/01/2019] Kernel: Added experimental Z80DMA (on port $0B) driver for I/O operations, configurable via ESXDOS.CFG file (lordcoxis + LMN128)
[19/01/2019] Commands: Updated .more and .dumpmem commands (ub880d)
[19/01/2019] TR-DOS: Added $052E trap, which fixes Headball GS (lordcoxis + reported by Hood)
[16/03/2019] FAT: Added utime() syscall (lordcoxis + requested by Pavel Vymetalek)
[17/03/2019] FAT: Fixed utime() syscall (ub880d)
[26/03/2019] Commands: Added .sercp (Pavel Vymetalek)
[19/04/2019] Kernel: Fixed M_DOSVERSION syscall (lordcoxis + ub880d)
[15/06/2019] Kernel: Fixed infinite loop when ESXDOS.SYS cannot be loaded (lordcoxis + reported by UB880D)
[16/06/2019] Flasher: Added MB03+ IDE/MMC flasher (LMN128)
[16/06/2019] Kernel: Fixed crash when no device is present (lordcoxis)

Thanks/Greets
-------------

Greets to all the usual peeps (y'all know who you are - just check v0.8.5's README if in doubt!).
Special thanks to all the great "hardware benefactors": Ben Versteeg, Pavel Urbancik, Pavel Vymetalek, SpecNext Team, Tygrys, UB880D, Zaxon!

Known Bugs
----------

128K Support: Need to run an esxDOS BASIC command before .commands will work
BASIC/Tape Emulator: You can overwrite ESXDOS system using LOAD CODE that crosses $2000
Commands: Proper argument/syntax checking is not done yet on most commands
Commands/BASIC: No wildcards yet
FAT Driver: rename() isn't even remotely posix compliant
FAT Driver: Directories read-only attribute isn't always respected
BIOS: Version of system file isn't checked against the ROM version (bad things will happen if there's a mismatch)
TR-DOS: FORMAT and MOVE commands don't work yet + too many to list ;)

16.06.2019 / Papaya Dezign - All rights perversed
