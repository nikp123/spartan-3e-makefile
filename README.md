# Example project for an XEM3001 (Spartan 3E) board

Mostly based off of [this](https://github.com/duskwuff/Xilinx-ISE-Makefile).

It's mostly the same except for the testing framework which I completely removed.

Instead, I replaced it with some other gtkwave Makefile which can be [found here](https://gist.github.com/etiennecollin/198f7520c4c58d545368a196e08f83ed)

# How do I run this

First, read the Xilinx-ISE-Makefile's documentation, then come back here.

Change the ``project.cfg`` file to match your setup. For example I use distrobox
to run ISE and a custom Opal Kelly programmer I can't share due to grayish 
copyright reasons.

# Building

Almost the same as the original repo:
```sh
make - builds the program
make program - programs the board
make simulate - see simulation results
```

# License
Public domain, same as the other two authors.

# Goals
 - Port to yosys, avoiding ISE tooling as much as possible

