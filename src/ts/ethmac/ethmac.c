//
// (C) 2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 3
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
//  02110-1301, USA.
//

void main (void)
{
        float value = 0;
        float *z = (float*) 0xffff0000; //EthMAC Base Address. Just want to check basic access to EthMac.
        *z = 0xDEADBEEF; //Writing to base register of EthMAC
        value = *z; //Reading from EthMAC Base address ...
}

////////////////// VECTORS /////////////////////////

void __undef(void) {
        return;
}

void __swi (void) {
        return;
}

void __pabt (void) {
        return;
}

void __dabt (void) {
        return;
}

void __irq (void) {
        return;
}

void __fiq (void) {
        return;
}
