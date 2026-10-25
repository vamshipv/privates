# Homies Hangout (Virtual Clan Hall)

A lightweight, low-latency 3D virtual clan hall built with **Godot 4.3 (Forward+ Vulkan)** for PC Desktop (Windows/macOS/Linux).

## Features
- **Grand 80m × 80m Clan Hall**: Scaled modular sci-fi room environment with Forward+ volumetric fog, glowing lighting, and static colliders.
- **Animated 3D Character**: Seamlessly plays native FBX animations (`Root|Idle`, `Root|Run`, `Root|Jump`) via `AnimationPlayer`.
- **Toggleable Camera**: Switch freely between First-Person (head-level) and Third-Person (SpringArm3D orbit) with `C` or mouse wheel zoom.
- **Networked Physics**: Grab (`E`), 3D rotate (`R` + Mouse), precision stack (`Right-Click`), and throw (`Left-Click`) physics props with dynamic client-authority handover.
- **Dynamic Ragdolls**: Flop and recover with `F`, or ragdoll upon high-speed physics impacts.
- **Low-Latency Multiplayer**: Direct UDP networking via `ENetMultiplayerPeer` on port 7777.
- **Spatial 3D Voice & Text Chat**: Positional proximity VoIP using `AudioEffectCapture` on the Record bus, plus timestamped HUD text chat and 3D overhead speech bubbles.

## Controls
| Action | Key / Input |
|---|---|
| **Move / Sprint** | `W`, `A`, `S`, `D` / `Shift` |
| **Jump** | `Space` |
| **Toggle Camera (1st/3rd Person)** | `C` or Mouse Wheel |
| **Grab / Drop Prop** | `E` |
| **Rotate Held Object** | Hold `R` + Move Mouse |
| **Stack / Place Gently** | `Right-Click` |
| **Throw Prop** | `Left-Click` |
| **Ragdoll Flop / Get Up** | `F` |
| **Push-To-Talk (VoIP)** | Hold `V` |
| **Text Chat** | `Enter` (Type & send) / `Esc` (Unfocus) |
| **Pause / Network Menu** | `Esc` |

## Getting Started
Open the project in Godot 4.3 or launch via the console executable:
```bash
Godot_v4.3-stable_win64_console.exe --path .
```
To run multiplayer sessions:
```bash
# Host
Godot_v4.3-stable_win64_console.exe --path . --host

# Client
Godot_v4.3-stable_win64_console.exe --path . --join 127.0.0.1
```
