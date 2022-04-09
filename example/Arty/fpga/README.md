# Verilog Ethernet Arty Example Design

## Introduction

This example design targets the Digilent Arty FPGA board.

The design by default listens to UDP port 1234 at IP address 192.168.1.128 and
will echo back any packets received.  The design will also respond correctly
to ARP requests.  

*  FPGA: XC7A35TICSG324-1L
*  PHY: TI DP83848J

## How to build

Run make to build.  Ensure that the Xilinx Vivado toolchain components are
in PATH.  

## How to test

Run make program to program the Arty board with Vivado.  Then run

    netcat -u 192.168.1.128 1234

e.g. hi\n shows on wireshark eth1 as:

    Eth II: 7444014e1e7b1c8341283b830800
    IPv4: 4500001f1ef040004011948bc0a80482c0a80180
        (https://www.omnisecu.com/tcpip/ipv4-protocol-and-ipv4-header.php)
        V/L     = 45 
        DSF     = 00 
        len     = 001f 
        ID      = 3d21 
        flags   = 4000 
        TTL     = 40 ('d64) 
        proto   = 11 (UDP) 
        hdr chk = 765a 
        src IP  = c0a80482 
        dst IP  = c0a80180
    UDP: ea9904d2000b876f
        src port = e2be 
        dst port = 04d2 ('d1234)
        length   = 000b 
        chksum   = 876f
    "hi\n": 68690a

to open a UDP connection to port 1234.  Any text entered into netcat will be
echoed back after pressing enter.

It is also possible to use hping to test the design by running

    hping 192.168.1.128 -2 -p 1234 -d 1024
