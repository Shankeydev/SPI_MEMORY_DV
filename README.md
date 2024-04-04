# SPI_MEMORY_DV
Design of SPI (Serial peripheral interface) memory controller to control a 32X8 byte addressable memory.
The memory and the controller connect through MISO and MOSI pins for transafer of data for read and write operations.
The design module contains a top module in which the memory and the controller both are instantiated.
The verification environment that drives the controller for read and write operations is written in UVM.
Test bench contains a 4 sequences one each for write data, read data, write data error and read data error.
