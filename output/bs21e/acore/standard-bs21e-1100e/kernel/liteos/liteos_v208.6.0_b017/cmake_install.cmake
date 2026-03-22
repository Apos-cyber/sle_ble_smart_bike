# Install script for directory: /home/hesheng/sle_ble_smart_bike/src/kernel/liteos/liteos_v208.6.0_b017

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "TRUE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/home/hesheng/sle_ble_smart_bike/src/tools/bin/compiler/riscv/cc_riscv32_musl_b010/cc_riscv32_musl_fp/bin/riscv32-linux-musl-objdump")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/arch/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/targets/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/kernel/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/lib/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/drivers/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/shell/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/compat/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/fs/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/home/hesheng/sle_ble_smart_bike/src/output/bs21e/acore/standard-bs21e-1100e/kernel/liteos/liteos_v208.6.0_b017/Huawei_LiteOS/net/cmake_install.cmake")
endif()

