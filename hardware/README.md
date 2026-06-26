# Hardware - enclosure

3D-printable parts for the ESP32-S3 reception microphone device: the round enclosure that houses the board and microphone.

## Overview

The physical device is housed in a single round **enclosure** made of two parts: a **body** that holds the ESP32-S3 board and microphone, and a **cap / front cover** with the microphone hole. Files are provided as `.step` parametric CAD sources for editing/remixing. Renders are in [`../assets/`](../assets/).

## Tech / stack

- **`.step`**: parametric CAD source, a neutral exchange format that imports into any CAD tool (Fusion 360, FreeCAD, SolidWorks, Onshape, etc.).

## Structure

```
hardware/
└── enclosure/
    ├── mic-v7-main.step           # Round body - holds the ESP32-S3 board and microphone
    └── mic-v7-case-mic-hole.step  # Cap / front cover with the microphone hole
```

## Build & run

Open a `.step` file in your CAD tool to edit or remix, then export a mesh to your slicer to print. Suggested starting settings for FDM printing (tune to your printer and material):

- **Material:** PLA
- **Layer height:** ~0.2 mm
- **Infill:** 15-20%
- **Supports:** as needed (depends on part orientation)

These are suggested defaults, not strict requirements. Adjust orientation, supports, and infill to suit your printer.

---

[← project root](../README.md)
