# Snake on FPGA

Real-time streaming graphics system implementing Snake on FPGA with VGA output and wireless PS5 controller support.

## Hardware

- **FPGA:** Basys 3
- **Controller:** PS5 DualSense
- **Bridge:** ESP32
- **Display:** VGA monitor (640×480 @ 60Hz)

## Features

**Graphics & Game Logic:**
- VGA 640×480 @ 60Hz output
- Snake (green 16×16 sprite) with WASD-style movement
- AABB collision detection
- State machine: MENU → PLAYING → VICTORY/GAMEOVER
- 16-LED animated status display

**Input & Control:**
- **PS5 DualSense wireless controller** via ESP32 bridge (see `esp32/`)
- UART receiver (115200 baud, 16× oversampling)
- Packet-based command routing (Player/Bullet/Enemy)

## Quick Start

1. **FPGA:** Synthesize and program nexys a7 with `rtl/` sources
2. **ESP32:** Wire GPIO17→C17, GPIO16←D18, GND→GND
3. **Controller:** Follow `esp32/README.md` for DualSense controller setup
4. **Play:** Press PS button, game auto-starts

## Architecture
PS5 Controller (BLE) → ESP32 → UART → stream_adapter → stream_router
                                           ↓
                            ┌───────────────┼───────────────┐
                            ↓               ↓            
                        Snake              Food       
                            ↓               ↓            
                        Collision Detection (spatial_intersect)
                            ↓
                        VGA Mixer (Priority: Bullet > Player > Enemies)
                            ↓
                        VGA Output 


## Controls

- **D-Pad / Left Stick:** Move snake
- **OPTIONS:** Restart game

## Packet Format

8-byte UART packets @ 115200 baud:

| Byte | Field | Values |
|------|-------|--------|
| 0 | Type | 0x01=Player, 0x03=Enemy |
| 1 | Direction | 0=none, 1=up, 2=down, 3=left, 4=right, 9=START |
| 2 | Action | 0=none, 1=shoot |
| 3-7 | Reserved | 0x00 |