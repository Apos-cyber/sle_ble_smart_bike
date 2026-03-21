#===============================================================================
# @brief    Smart riding samples
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
#===============================================================================

if(CONFIG_SAMPLE_SUPPORT_SMART_RIDING_LIGHT)
    add_subdirectory_if_exist(smart_riding_light)
endif()

if(CONFIG_SAMPLE_SUPPORT_BUZZER)
    add_subdirectory_if_exist(Functional_module/buzzer)
endif()

if(CONFIG_SAMPLE_SUPPORT_MPU6050)
    add_subdirectory_if_exist(Functional_module/mpu6050)
endif()

if(CONFIG_SAMPLE_SUPPORT_SMART_RIDING_TEST)
    add_subdirectory_if_exist(test/ble_test)
    add_subdirectory_if_exist(test/sle_test)
endif()

set(SOURCES "${SOURCES}" PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" PARENT_SCOPE)
set(PUBLIC_DEFINES "${PUBLIC_DEFINES}" PARENT_SCOPE)
