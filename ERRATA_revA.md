1) BUS_N_ROMCS - нет pull-down 10к резистора в схеме и на плате
2) BUS_N_IORQGE - нет pull-down 10k резистора в схеме и на плате
3) TAPE_IN - нет конденсатона 10нФ последовательно с R22 в схеме и на плате
4) Footprint под Z80 имеет некоррентный размер QFP-10x10mm, а нужен QFP-12x12mm, приходится гнуть ноги у процессора
5) Разъем JTAG - если ставить shrouder header, налазит на рядом стоящие резисторы

