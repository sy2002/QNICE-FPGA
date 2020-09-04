Interrupt capable devices
=========================

QNICE-FPGA features a Daisy chain architecture for interrupt capable devices.
At the very "left" side of this chain is the CPU, then the devices are
chained together:

```
CPU <=> Device 1 <=> Device 2 <=> ... <=> Device n
```

Each interrupt capable device needs to follow the protocol specified in this
file, otherwise the chain might break and/or very difficult to reproduce
bugs might occur.

Basic mechanism
---------------

Please read the file [doc/intro/qnice_intro.pdf](intro/qnice_intro.pdf) for
all the details. Here is the summary:

* The CPU features two lines to deal with external interrupts, both lines have
  inverted logic, i.e. `1` is `inactive` and `0` is `active`.
  ```
  INT_N          : in std_logic;
  IGRANT_N       : out std_logic;  
  ```

* To request an interrupt, a device is pulling `INT_N` to `0`.

* As soon as the CPU is able to service the interrupt, it will pull
  `IGRANT_N` to `0`. This means, that the device shall now put the address of
  the desired ISR onto the data bus.

* As soon as the data is valid, the device pulls `INT_N` back to `1`.

* The CPU now reads the data and pulls `IGRANT_N` to `1` to notify the device
  that it must release the data bus. The CPU then jumps to this address and
  executes the ISR.

![Interrupt_Timing](intro/interrupt_timing.jpg)

Daisy chaining
--------------

* The basic idea of the Daisy chaining protocol used at QNICE-FPGA is that
  no device is aware of its "position" within the Daisy chain. It might be
  located right next to the CPU or it might be located "far away".

* Every interrupt capable device must support the following signals:
  ```
  -- "left/right" comments are meant to describe a situation, 
  -- where the CPU is the leftmost device
  int_n_out      : out std_logic;    -- left device's interrupt signal input
  grant_n_in     : in std_logic;     -- left device's grant signal output
  int_n_in       : in std_logic;     -- right device's interrupt signal output
  grant_n_out    : out std_logic;    -- right device's grant signal input  
  ```
  In this description, "left" is a device (or the CPU) that has the authority
  to grant an interrupt to the "right" device. Ultimately this authoritry
  stems from the CPU, of course. Due to the very nature of the Daisy chain
  mechanism, an **interrupt request** is passed from device to device to "the
  left" until it reaches the CPU and an **interrupt grant** is passed from
  device to device to "the right" until it reaches the requesting device.

* There are two very important mechanism, that needs to be built into all
  interrupt capable devices: 


  1. X

  2. Y

* This all means also: The "closer" a device is to the "left" (i.e. near
  to the CPU), the higher is the priority of its interrupts.