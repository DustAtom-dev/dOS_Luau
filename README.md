# An Operating System for WoS

## What is dOS?
dOS_Luau or "dOS" is an Operating System (OS) written entirely in Pilot.lua, a programming language derived from Roblox Luau (rbx.lua) and made specifically for a Roblox game called "Waste of Space" (WoS or WOS).

## Why such thing?
My goal was to build the best OS in WoS, inspired by many others that attempted such challenge.

## Why is it so messy?
As you may have already seen, the architecture is flawed, and this is because for a long time dOS was one-file. It is only months later that I discovered the Pilot.lua linter and darklua, which both made my life so much easier.

## How can I try it?

First, clone this repository and go to the project root.

### Game setup
If you have Roblox, join the Waste of Space game.
Then, you'll need a "computer" system.
The simplest is a Microcontroller at the center, two ports attached to it, and finally a TouchScreen attached to the first port, and a Keyboard to the second.
Do note that you'll need Disks for persistence, Speaker for sound, and other TouchSreens for secondary displays. Ports are mandatory.

### Host Setup
#### Windows
- Download, install, and add darklua to your PATH. You can download a portable standalone EXE if available, and drag-n-drop it in the root of this project.
- Run `build.cmd`

#### UNIX-like OSes
- Open a terminal in the project root
- Run:
```bash
bash build.sh
```

---

Now, you can copy the content of `OUTPUT/out.luau` and paste it in the Microcontroller.
Note: To open see the Microcontroller content, hold the "hammer" tool, click "Config", click the Microcontroller, and you have a TextBox in which you can paste the code and then **Apply**.

**Click the Microcontroller once with no tools in your hand to start the code.**

> If it does not work, **press *F9*** to open the Developer Console.
