#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
#===============================================================================

if(DEFINED CONFIG_SAMPLE_SUPPORT_SMART_RIDING_LIGHT)
    set(SOURCES_LIST
        ${CMAKE_CURRENT_SOURCE_DIR}/rgb_matrix_8x8_demo.c
        ${CMAKE_CURRENT_SOURCE_DIR}/rgb_matrix_patterns.c
    )
endif()

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
