# PongWIC64
This is a project of the classic Pong game in a network version based on a client-server structure. The server is a modern PC or Raspberry Pi, while the two clients are Commodore 64 computers.

The server code is written in Python 3.x, while the client code is written in ACME assembler. The repository includes a solution for C64Studio.

To run the game you need a WIC64 cartridge or the VICE emulator (tests were performed on version 3.9), which enables WIC64 emulation.
Start the server with the command:

```python
python -m main
```

Then run the client.prg program on each client and enter the server's IP address and port.

Unfortunately, the game does not behave stably on real hardware, which is probably the cause of transmission errors on the WIC64-C64 line. The game works correctly only on emulators. I suggest testing the program on your own hardware. I invite you to participate in improving and enhancing PongWIC64.
