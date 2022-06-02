# Makefile - GNU Makefile
#
# Copyright (c) 2022 Andy Karpov.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

SRC_DIVMMC=src/esxdos.rom src/128-0.rom src/128-1.rom
SRC_ZC=src/gluk.rom src/trdos.rom src/128p-0.rom src/128p-1.rom
IMAGES=divmmc-27c512.rom divmmc-29ee010.rom divmmc-29ee020.rom divmmc-29ee040.rom zc-27c512.rom zc-29ee010.rom zc-29ee020.rom zc-29ee040.rom

all: $(IMAGES)

divmmc-27c512.rom: $(SRC_DIVMMC)
	cat src/esxdos.rom > divmmc-27c512.rom
	cat src/esxdos.rom >> divmmc-27c512.rom
	cat src/esxdos.rom >> divmmc-27c512.rom
	cat src/esxdos.rom >> divmmc-27c512.rom
	cat src/128-0.rom >> divmmc-27c512.rom
	cat src/128-1.rom >> divmmc-27c512.rom

divmmc-29ee010.rom: divmmc-27c512.rom
	cat divmmc-27c512.rom > divmmc-29ee010.rom
	cat divmmc-27c512.rom >> divmmc-29ee010.rom

divmmc-29ee020.rom: divmmc-29ee010.rom
	cat divmmc-29ee010.rom > divmmc-29ee020.rom
	cat divmmc-29ee010.rom >> divmmc-29ee020.rom

divmmc-29ee040.rom: divmmc-29ee020.rom
	cat divmmc-29ee020.rom > divmmc-29ee040.rom
	cat divmmc-29ee020.rom >> divmmc-29ee040.rom

zc-27c512.rom: $(SRC_ZC)
	cat src/gluk.rom > zc-27c512.rom
	cat src/trdos.rom >> zc-27c512.rom
	cat src/128p-0.rom >> zc-27c512.rom
	cat src/128p-1.rom >> zc-27c512.rom

zc-29ee010.rom: zc-27c512.rom
	cat zc-27c512.rom > zc-29ee010.rom
	cat zc-27c512.rom >> zc-29ee010.rom

zc-29ee020.rom: zc-29ee010.rom
	cat zc-29ee010.rom > zc-29ee020.rom
	cat zc-29ee010.rom >> zc-29ee020.rom

zc-29ee040.rom: zc-29ee020.rom
	cat zc-29ee020.rom > zc-29ee040.rom
	cat zc-29ee020.rom >> zc-29ee040.rom

clean:
	rm -f $(IMAGES)

