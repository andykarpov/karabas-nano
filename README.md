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

**Latest revision:** rev.G.

Forum topic with discussion, new features and bugs is here: [zx-pk.ru](https://zx-pk.ru/threads/30806-karabas-nano.html). (mostly russian-only).

License for this project is **WTFPL**. [More details here](https://github.com/andykarpov/karabas-nano/blob/master/LICENSE.md).


### Pre-production renders:

![image](https://github.com/andykarpov/karabas-nano/raw/master/docs/photos/karabas-nano-revG-top.png)

![image](https://github.com/andykarpov/karabas-nano/raw/master/docs/photos/karabas-nano-revG-bottom.png)

