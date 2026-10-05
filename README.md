# FPGA Two-Player Fighting Game (DE1-SoC)

A complete two-player fighting game — inspired by *Footsies* — implemented
entirely in hardware on a Terasic DE1-SoC (Cyclone V) FPGA. No processor, no
software: just synchronous digital logic in Verilog driving a VGA monitor in
real time.

Built as a term project for EE314 (Digital Circuits Laboratory), METU.

## Overview

Two players face off on a rendered VGA display. Each can move, throw a quick
basic attack or a slower special, and block by walking backward. The goal is to
read your opponent's spacing, land attacks, break their guard, and win three
rounds. Everything you see — background, characters, on-screen text, HUD, and
the status on the board's 7-segment displays and LEDs — is generated live by the
FPGA.

## Features

- **640×480 @ 60 Hz VGA output** via the on-board ADV7123 DAC (3-3-2 colour)
- **Two independently controlled characters** (P1 on the board buttons, P2 on an
  external keypad wired to the GPIO header)
- **Movement** with speed limits and collision constraints (no crossing, no
  leaving the screen)
- **Basic and special attacks**, each with distinct startup/active/recovery
  frame data; the special has two triggers (charge-and-release, or cancel from a
  connected basic)
- **Blocking, a depletable guard meter, and guard-break** when the guard is
  broken
- **Hitbox / hurtbox collision detection** (axis-aligned bounding box) with
  hitstun, blockstun, and knockouts
- **Round and match tracking** with on-screen banners, 7-segment score, and LED
  indicators
- **Single-step debug mode** — freeze the game and advance one frame at a time,
  with a switchable overlay that draws hitboxes (red) and hurtboxes (yellow) to
  verify collisions frame-by-frame

## Design Highlights

- **Single clock domain.** Every module is clocked by the 50 MHz board clock and
  advances only on a one-cycle `game_en` enable pulse (60 Hz in normal play).
  This avoids gated/divided clocks, keeps timing closure trivial, and makes the
  single-step debug mode almost free — `game_en` is simply re-sourced from a
  button.
- **No framebuffer.** The renderer is fully combinational: each pixel's colour is
  computed on the fly as the beam scans, including a scaled 8×8 bitmap-font
  engine for all on-screen text.
- **Frame-domain input conditioning.** Buttons are synchronized, debounced, and
  edge-detected in the 60 Hz game domain so presses always line up with when the
  logic samples them.
- **Latched hit detection.** A per-attacker latch ensures a multi-frame active
  window registers at most one contact, preventing double damage.

## Architecture

Ten cooperating Verilog modules:

| Module            | Role                                                        |
|-------------------|-------------------------------------------------------------|
| `top`             | Top level — instantiates and wires all modules              |
| `clock_divider`   | 25 MHz pixel clock + `game_en` frame tick (and debug step)  |
| `debounce`        | Synchronize / debounce / frame-domain edge detection        |
| `player_fsm`      | Per-character 12-state machine (movement, attacks, reactions)|
| `round_manager`   | Match FSM — menu, countdown, rounds, match win              |
| `hit_detection`   | AABB overlap resolution → hit / block / guard-break / KO    |
| `vga_controller`  | 640×480 timing, sync signals, pixel coordinates             |
| `vga_renderer`    | Per-pixel colour: sprites, text, HUD, debug overlay         |
| `seg7_driver`     | 7-segment status (sides, `P1 VS P2`, final score)           |
| `led_driver`      | LED round-win indicators + game-over blink                  |

## Controls

**Switches**
- `SW0` — run / reset (up = run)
- `SW1` — debug clock (up = single-step via `KEY3`)
- `SW9` — hitbox/hurtbox overlay

**Player 1** (on-board buttons): `KEY0` left, `KEY1` right, `KEY2` attack/confirm
**`KEY3`** — debug frame-step
**Player 2** (GPIO keypad): left / right / attack

Attacks: tap = basic, hold ~0.75 s and release = special, or press attack again
during a connected basic's recovery to cancel into the special. Block by holding
backward.

## Verification

- Self-checking integration testbench driving the game logic frame-by-frame
  (28 / 28 assertions passing)
- Renderer verified by dumping simulated framebuffers per game state and
  inspecting them
- Every feature validated on real hardware, using the single-step + overlay mode
  to confirm frame-accurate behaviour

## Build

Open `EE314FINPROJ.qpf` in Intel Quartus (Lite), compile, and program the
`.sof` onto the DE1-SoC's FPGA device over JTAG. Set `SW0` up to run.

## Authors

- Armaghan Imran
- Nasbat Nassor Al Jahwari
- Ahmed M M Osman

Term project for EE314, Middle East Technical University.
