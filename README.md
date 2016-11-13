# OpenTx Lua Scripts for AutoQuad

This repository contains some Lua scripts to support [AutoQuad's](http://autoquad.org) custom telemetry format when used with FrSky S-Port protocol and [OpenTx](http://www.open-tx.org) firmware.

![AutoQuad Custom S-Port Telemetry](http://forum.autoquad.org/download/file.php?id=7624&mode=view)

## Requirements

1. [AutoQuad firmware version 7.1.1923](https://github.com/mpaperno/aq_flight_control/) or above. Enable S-Port telemetry and select "Send custom data" option.
2. Appropriate serial connection to FrSky X-series Rx (an adapter is required, [see below](#serial-adapter)).
3. OpenTx v2.0 or above with Lua scripting enabled.

**Note: OpenTx 2.1.x** not tested yet and will require some extra setup.  See `SCRIPTS/MIXES/TFlds21x.lua` file.

## Setup

### Scripts

Scripts are organized into two types.  The *MIXES* scripts run in the background and provide supporting functions, while the *TELEMETRY* scripts provide the actual display
screen(s). You will find corresponding folders inside the SCRIPTS folder of this repository. This is organized the same as the SD card folder structure on your radio.

#### MIXES scripts

1. *AQTelem* - This is the main parser for all the custom telemetry data fields coming from AutoQuad. It provides converted telemetry values and a few useful functions for 
use in display scripts.  It also provides several outputs which can be used to set up logic switches/sound alerts/etc.  It is worth reading through all the comments in this file.

2. *DrawLib* - This is a collection of useful functions for drawing on the LCD (eg. circle or arrow), and also provides some conversion and formatting functions.

3. *TFlds2xx* - This is a "compatibility layer" script to provide compatibility with OpenTx version 2.0 and 2.1.  v2.1 changed how all the telemetry fields are named,
so this method was used instead of needing two completely separate code bases for the different OTx versions. The exact file you want to use depends on the OTx version -- 
`TFlds20x` for OpenTx 2.0.x and `TFlds21x` for OpenTx 2.1.x (and above, assuming the system doesn't change again).

To use *MIXES* scripts, first copy the **`.luac`** versions from the *SCRIPTS/MIXES* folder of this repo to the corresponding folder on your Taranis/Horus SD card.
**Rename** them with a `.lua` extension (see [Plain-text vs. pre-compiled](#plain-text-vs-pre-compiled-versions) section).
Then go to the OTx *CUSTOM SCRIPTS* setup screen of your model, select a blank slot ("LUAn"), hit [ENT], then again to select a script from the MIXES folder on SD card.
Do this for each of the 3 scripts above.  Once done with all 3 and back on the *CUSTOM SCRIPTS* screen, make sure none of the loaded scripts say "error" next to them.

#### TELEMETRY scripts

1. *telem1* - Main "all-in-one" telemetry desplay script showing many different values (see screenshot at top).

2. *telem1-light* - A simpler version of *telem1* with some features simply commented out. Use this as starting point for modifications -- and read the 
[Plain-text vs. pre-compiled](#plain-text-vs-pre-compiled-versions) section.

3. *telem2* - This script displays text messages from AutoQuad.  This is an experimental feature and may or may not work well in your setup. Sending of text messages needs to be enabled in
AQ S-Port settings for this to work at all.

4. *telem5-debug* - Simple data display script for development/debugging your own scripts.

To use *TELEMETRY* scripts:

- **OpenTX 2.0:** You will need to create a folder on the SD card, inside the *SCRIPTS* folder, using the same name as your model (eg. "AutoQuad"). Remove all spaces from the folder name if
you model name it has any.  Then put the `telemX.lua` files you want to use (or `.luac`, see below) in that folder.  Next time you select that model, the scripts will be loaded (long-press [PAGE] key to view them).

- **OpenTX 2.1 (& later):** Simply copy the contents of the *TELEMETRY* folder from this repo to the *SCRIPTS/TELEMETRY* your SD card (create it if you don't have one already).  
You can then go into the model settings and select which display script(s) you want to run from this folder.  This way is much easier to share the same scripts between models.

**For *telem1* script** you must use the pre-compiled `.luac` version, then rename if to `.lua` once on the SD card. The plain-text version is too large to load properly.  Read below for details.

### Plain-text vs. pre-compiled versions

The scripts all come in two versions, plain-text (`.lua`) and pre-compiled "bytecode" versions (`.luac`).  The short story is that the memory on the Taranis/etc is very limited. 
Large Lua scripts may consume too much memory to work at all.  One workaround is to pre-compile the scripts, which reduces memory usage considerably.

**`.luac` files must be renamed to `.lua` on the Taranis before they will work.** Unfortunately OTx doesn't support the `.luac` naming convention yet.

It will not be possible to run all the plain-text versions of the scripts on the actual radio (though they work fine in the OTx simulator). On the other hand there is no publicly
available method to compile your own versions.

If you want to customize the telemetry display scripts, I recommend you at minimum run the `.luac` versions of `AQTelem.luac` and `DrawLib.luac`. Make all your changes in the
`telemX.lua` plain-text versions and then after it works in the simulator try it on the radio to make sure there is enough memory.

Currently the main display script (`telem1.lua`) is too large to run as the plain-text version on the Taranis. So I've also provided a "light" version of it (`telem1-light.lua`) 
which works on the Taranis w/out being pre-compiled (as long as `AQTelem` and `DrawLib` are).  This is simply the full script but with some parts commented out.  If you want to 
modify the display, I would start with the "light" version.

## Serial Adapter

To connect an FrSky S-Port Rx to AQ, a serial port an adapter is necessary -- same thing as required for PX4/ArduCopter for instance.  It's fairly easy to 
[build your own](https://github.com/TauLabs/TauLabs/wiki/User-Guide:-FrSKY-S.PORT-telemetry#making-the-connection), make one out of two existing FrSky adapters 
([FUC-1 and SPC (which is just a diode)](http://ardupilot.org/copter/docs/common-frsky-telemetry.html#diy-cable-for-x-receivers)), or buy some pre-made ones eg. 
[https://www.airborneprojects.com/product/apm-mavlink-to-frsky-smartport-converter/]  or  [http://www.craftandtheoryllc.com/product-category/telemetry/].


## Author

    Maxim Paperno - MPaperno@WorldDesign.com
    https://github.com/mpaperno/AQ-QTx-Lua


## Copyright, License, and Disclaimer

Copyright (c)2015-2016 by Maxim Paperno. All rights reserved.

       This program is free software: you can redistribute it and/or modify
       it under the terms of the GNU General Public License as published by
       the Free Software Foundation, either version 3 of the License, or
       (at your option) any later version.

       This program is distributed in the hope that it will be useful,
       but WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
       GNU General Public License for more details.

       You should have received a copy of the GNU General Public License
       along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
