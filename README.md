![Index OS logo](logo.svg)
## A custom launcher for the Panic Playdate.

By [scratchminer](https://github.com/scratchminer) and [Rae](https://stuffbyrae.neocities.org/)

### Building from source
Use the Playdate Compiler from Playdate's SDK: `pdc -v Source IndexOS.pdx`

### Installing
#### On hardware
1. Download the Index Installer from the website or releases page (todo: actually post it)
2. Sideload the PDX to your device, or place it directly in the data disk somewhere in the `Games` folder.
3. On your Playdate, launch the installer and follow the on-screen prompts.

#### On the Playdate Simulator
1. Build the Index OS core application yourself, or download it from the website or releases page.
2. Navigate to wherever you installed the Playdate SDK, then go to `<SDK path>/Disk/System`.
3. Rename the existing application `Launcher.pdx` to somthing else, like `StockLauncher.pdx`.
4. Drag Index OS into the `System` folder and rename it `Launcher.pdx`.
5. Launch Index OS with the Playdate Simulator.

---

This project isn't affiliated with [Panic](https://panic.com/), the makers of the [Playdate](https://play.date/), in any way.