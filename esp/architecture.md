# Snake-On-FPGA — System Architecture

## Top-Level Block Diagram

```mermaid
graph LR
    subgraph "External I/O"
        UART_PIN["i_uart_rx"]
        CLK["i_clk"]
        RST["i_rst_n"]
        VGA_OUT["o_vga_r/g/b\no_vga_hsync\no_vga_vsync"]
        LED_OUT["o_led[15:0]"]
    end

    CLK --> BAUD & UART_RX & ADAPTER & ARBITER & ROUTER & VGA & CTRL & SCHED & OBJ0 & OBJ1 & GROUP & COLLIDER & STATUS & MIXER
    RST --> BAUD & UART_RX & ADAPTER & ARBITER & ROUTER & VGA & CTRL & SCHED & OBJ0 & OBJ1 & GROUP & COLLIDER & STATUS & MIXER

    subgraph "UART Receive Chain"
        BAUD["clk_divider\n(baud_gen)"]
        UART_RX["uart_rx\n(uart_receiver)"]
        ADAPTER["stream_adapter\n(uart_converter)"]
    end

    subgraph "Packet Infrastructure"
        SCHED["scheduler_core\n(event_generator)\n⚠ MISSING"]
        ARBITER["stream_arbiter\n(packet_combiner)"]
        ROUTER["stream_router\n(router)"]
    end

    subgraph "Control Plane"
        CTRL["system_controller\n(state_manager)"]
        STATUS["status_indicator\n(status)\n⚠ MISSING"]
    end

    subgraph "Render Pipeline"
        OBJ0["render_object_0\n(object_0)\n⚠ MISSING"]
        OBJ1["render_object_1\n(object_1)\n⚠ MISSING"]
        GROUP["render_group\n(element_group)\n⚠ MISSING"]
        VGA["vga_timing\n(vga_tim)"]
        COLLIDER["spatial_intersect\n(collider)"]
        MIXER["VGA Mixer\n(always block)"]
    end

    UART_PIN --> UART_RX
    BAUD -->|"w_baud_tick"| UART_RX
    UART_RX -->|"w_uart_data[7:0]\nw_uart_valid"| ADAPTER
    ADAPTER -->|"w_uart_axis_tdata[63:0]\nw_uart_axis_tvalid\nw_uart_axis_tlast"| ARBITER
    ARBITER -->|"w_uart_axis_tready"| ADAPTER

    SCHED -->|"w_timer_axis_tdata[63:0]\nw_timer_axis_tvalid\nw_timer_axis_tlast"| ARBITER
    ARBITER -->|"w_timer_axis_tready"| SCHED

    CTRL -->|"w_system_active"| SCHED

    ARBITER -->|"w_merged_axis_tdata[63:0]\nw_merged_axis_tvalid\nw_merged_axis_tlast"| ROUTER
    ROUTER -->|"w_merged_axis_tready"| ARBITER

    ROUTER -->|"w_player_tdata[63:0]\nw_player_tvalid\nw_player_tlast"| OBJ0
    OBJ0 -->|"w_player_tready"| ROUTER

    ROUTER -->|"w_enemy_tdata[63:0]\nw_enemy_tvalid\nw_enemy_tlast"| GROUP
    GROUP -->|"w_enemy_tready"| ROUTER

    ADAPTER -->|"w_start_button\n(derived)"| CTRL
    CTRL -->|"w_system_active"| OBJ0 & OBJ1 & GROUP & COLLIDER
    CTRL -->|"w_reset_pulse"| OBJ0 & OBJ1 & GROUP

    OBJ0 -->|"w_trigger"| OBJ1
    OBJ0 -->|"w_obj0_x/y[9:0]"| OBJ1

    OBJ1 -->|"w_obj1_x/y[9:0]\nw_obj1_active"| COLLIDER
    GROUP -->|"w_group_x/y[9:0]"| COLLIDER
    COLLIDER -->|"w_collision_detected\nw_hit_row[2:0]\nw_hit_col[3:0]"| GROUP
    COLLIDER -->|"w_collision_detected"| OBJ1

    GROUP -->|"w_active_count[4:0]"| CTRL & SCHED & STATUS
    GROUP -->|"w_halt_condition"| CTRL

    VGA -->|"w_pixel_x/y[9:0]\nw_video_on"| OBJ0 & OBJ1 & GROUP & MIXER
    VGA -->|"o_vga_hsync\no_vga_vsync"| VGA_OUT

    OBJ0 -->|"w_obj0_r/g/b[3:0]"| MIXER
    OBJ1 -->|"w_obj1_r/g/b[3:0]"| MIXER
    GROUP -->|"w_group_r/g/b[3:0]"| MIXER

    MIXER -->|"o_vga_r/g/b[3:0]"| VGA_OUT

    CTRL -->|"w_ctrl_state[1:0]"| STATUS
    STATUS -->|"o_led[15:0]"| LED_OUT
```

## Signal Flow Summary

### 1. UART Receive Chain
```
i_uart_rx → uart_rx → stream_adapter → stream_arbiter
                ↑
          clk_divider (w_baud_tick)
```
Serial bytes arrive on `i_uart_rx`, get deserialized by `uart_rx` (clocked at 16× baud via `clk_divider`), then `stream_adapter` assembles 8 bytes into a 64-bit AXI-Stream packet.

### 2. Packet Merging & Routing
```
stream_adapter ──┐
                 ├─→ stream_arbiter ──→ stream_router ──→ Port 0 (Player)
scheduler_core ──┘                                   ──→ Port 1 (Bullet, unused)
                                                     ──→ Port 2 (Reserved)
                                                     ──→ Port 3 (Enemy)
```
`stream_arbiter` merges UART packets (priority) with timer-generated packets. `stream_router` demuxes by packet type byte (`tdata[7:0]`): `0x01` → player, `0x02` → bullet, `0x03` → enemy.

### 3. Control Plane
```
w_start_button ──→ system_controller ──→ w_system_active (gates all movement)
w_active_count ──┘                   ──→ w_reset_pulse (resets render objects)
w_halt_condition ┘                   ──→ o_ctrl_state (MENU/PLAYING/VICTORY/GAMEOVER)
```
Derives `w_start_button` from UART packets (type `0x01`, direction `0x09`). State machine controls game lifecycle.

### 4. Render Pipeline
```
                    ┌─ render_object_0 (player) ─── w_trigger ──→ render_object_1 (projectile)
stream_router ──────┤                                                      │
                    └─ render_group (enemies) ←── collision ←── spatial_intersect ←─┘
```
- **render_object_0**: Player sprite, positioned by UART direction commands
- **render_object_1**: Projectile, spawns at player position on trigger
- **render_group**: Enemy grid, moves via scheduler packets
- **spatial_intersect**: AABB collision between projectile and enemy grid

### 5. VGA Output
```
vga_timing → pixel_x/y, video_on → all render objects
                                          ↓
obj0_rgb, obj1_rgb, group_rgb → VGA Mixer (priority: obj1 > obj0 > group) → o_vga_r/g/b
```
Priority compositing: projectile on top, then player, then enemies. Black = transparent.
