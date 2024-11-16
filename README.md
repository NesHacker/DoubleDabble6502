# DoubleDabble6502
An NES implementation of 8-bit Double Dabble

## Double Dabble Code
The code for Double Dabble and the VRAM printing routine are both in the
[src/doubledabble.s](./src/doubledabble.s) file. Look for the following:

- `.proc double_dabble`, and
- `.proc print_bcd`

The project also has a routine to check the controller D-PAD and add/subtract
rupees based on what button was pressed:

- `.proc update_rupees`

## Building
The project requires [`ca65`](https://cc65.github.io/) and '
[`make`](https://www.gnu.org/software/make/) and can be built by running `make`
from the project root.
