# Karabas-Nano

**Yet another ZX Spectrum clone ;)**

## Intro

ZX Spectrum compatible machine with real **Z80** CPU and all logic inside the CPLD Altera **EPM3256ATC144** (or EPM7512).

## The idea

The idea was to learn KiCAD and make a **cheapest** and **smallest** ZX Spectrum clone with minimum components and real CPU. 
Some parts of this schematics are grabbed from the **Karabas-128** and **ZX-UNO** projects (like RGB DAC, PAL coder, Tape-in logic).
The heart of this project is a real SMD Z80 CPU and ULA implementation on Altera CPLD EPM3256ATC144. 

## Firmwares

The board contains an SD card socket, so at least 2 different configurations are supported:

1) Z-Controller based configuration (Pentagon timings, GLUK reset service in the ROM bank 0, 1024kB of extended memory via port #DFFD (Profi))

2) DivMMC based configuration (Pentagon timings, ESXDOS 0.8.7 in the ROM bank 0, 128kB of memory)

## More info

**ERRATA for PCB rev.A:** [Russian](https://github.com/andykarpov/karabas-nano/blob/master/ERRATA_revA.md).

**ERRATA for PCB rev.B:** [Russian](https://github.com/andykarpov/karabas-nano/blob/master/ERRATA_revB.md).

**Latest revision:** rev.I.

License for this project is **WTFPL**. [More details here](https://github.com/andykarpov/karabas-nano/blob/master/LICENSE.md).

### Pre-production renders

![image](https://github.com/andykarpov/karabas-nano/raw/master/docs/photos/karabas-nano-revI-top.png)

![image](https://github.com/andykarpov/karabas-nano/raw/master/docs/photos/karabas-nano-revI-bottom.png)

### PCB Rev. H assembly example by [Xoomoh (Михайло Капітанов)](https://github.com/xoomoh/)

![revH_by_xoomoh-top.jpg](https://raw.githubusercontent.com/andykarpov/karabas-nano/master/docs/photos/mini/revH_by_xoomoh-top.jpg)

![revH_by_xoomoh-bottom.jpg](https://raw.githubusercontent.com/andykarpov/karabas-nano/master/docs/photos/mini/revH_by_xoomoh-bottom.jpg)

![revH_by_xoomoh-ic.jpg](https://raw.githubusercontent.com/andykarpov/karabas-nano/master/docs/photos/mini/revH_by_xoomoh-ic.jpg)
