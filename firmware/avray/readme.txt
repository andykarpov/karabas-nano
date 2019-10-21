AVR Emulator of IC AY-8910, AY-3-8910, AY-3-8912 for Atmega8,Atmega8A
Version 24.7
2ch version + beeper

Uploading:
	Use avrdude and USBAsp programmer:

        avrdude -p atmega8 -c USBasp -U flash:w:AY_Emul_247_2ch_m8_ay_speaker.hex -U eeprom:w:Conf_parallel_20MHz_1_75Mhz.hex -U lfuse:w:0xCE:m -U hfuse:w:0xCF:m

P.S. There are some quality problems with the latest version 25.0, so, it's seems that v.24.7 is the latest stable one.

ORIGIN: http://www.avray.ru
