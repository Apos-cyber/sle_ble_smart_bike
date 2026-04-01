# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a HiSilicon IoT chip SDK for smart bike/riding applications (智慧骑行). It supports multiple chip variants: **bs20**, **bs21e**, **bs22**, and **bs2x** (chip family).

## Build Commands

Build is CMake-based with Python wrapper:

```bash
# Full build with default settings
python build.py -chip=bs2x

# Clean build
python build.py -chip=bs2x -c

# Parallel build (e.g., 8 threads)
python build.py -chip=bs2x -j8

# Add compile defines (-def=XXX to add, -def=-:XXX to remove)
python build.py -chip=bs2x -def=MY_DEF=1

# Build specific component only
python build.py -chip=bs2x -component=my_component

# Use ninja generator instead of makefiles
python build.py -chip=bs2x -ninja

# Release/debug mode (affects disassembly info)
python build.py -chip=bs2x -release
```

Chip must be specified via `-chip=<chip_name>`.

## Code Architecture

### Directory Structure
- **application/** - User code and samples
  - **samples/smart_riding/** - Smart riding project (main focus)
    - **smart_riding_light/** - WS2812B RGB LED matrix driver via SPI
    - **Functional_module/** - MPU6050 accelerometer, buzzer modules
    - **test/** - BLE/SLE communication tests
  - **samples/peripheral/** - Peripheral driver examples (SPI, UART, I2C, DMA, etc.)
  - **samples/products/** - Product examples (BLE keyboard, RCU, air mouse, etc.)
  - **samples/nfc/** - NFC controller/tag examples
- **drivers/chips/bs2x/** - Main chip porting layer (arch, interrupt, clocks, PMU, etc.)
- **drivers/chips/<chip>/** - Chip-specific implementations
- **kernel/liteos/** - Huawei LiteOS kernel v208.6.0
- **middleware/** - OS utilities, services, app initialization
- **protocol/** - BT (Bluetooth), NFC, SLP protocol stacks
- **open_source/** - Third-party: GmSSL3.1.1 (Chinese crypto), libboundscheck

### Application Entry Flow
1. `main()` in `application/bs20/standard/main.c` → calls `main_init()`
2. `main_init()` in `drivers/chips/bs2x/main_init/main_init.c` - chip hardware init
3. `app_os_init()` in `drivers/chips/bs2x/main_init/app_os_init.c` - creates OS tasks
4. Sample tasks registered via `app_run(func)` macro in `middleware/utils/app_init/`

### Sample Registration Pattern
Samples use initcall sections. Add to a sample's C file:
```c
#include "app_init.h"

void my_sample_task(void)
{
    // sample code
}
app_run(my_sample_task);
```

### Kconfig System
- Configuration via `config.in` and Kconfig files
- Enable samples: `ENABLE_SAMPLE`, then specific sample enables (e.g., `ENABLE_SMART_RIDING_SAMPLE`)
- Target-specific configs: `build/config/target_config/<chip>/menuconfig/<target>/`

## Key Conventions

- Task priority 0-31: 0=SWT (highest), 1-10=protocol stack, 11-29=user, 30=low power, 31=IDLE (lowest)
- Logging via `osal_printk()` / `printk()`
- Error codes use `errcode_t` with `ERRCODE_SUCC`
- Pin configuration: `uapi_pin_set_mode(pin, function)`
