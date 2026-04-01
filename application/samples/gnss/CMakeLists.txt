#===============================================================================
# @brief    cmake file
# Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
#===============================================================================
set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/common/common_uart.c
    ${CMAKE_CURRENT_SOURCE_DIR}/common/cloud_common.c
    ${CMAKE_CURRENT_SOURCE_DIR}/gnss/gnss_pos.c
    ${CMAKE_CURRENT_SOURCE_DIR}/l610/L610.c
    ${CMAKE_CURRENT_SOURCE_DIR}/main.c
)
set(HEADER_LIST ${CMAKE_CURRENT_SOURCE_DIR}/common
    ${CMAKE_CURRENT_SOURCE_DIR}/gnss
    ${CMAKE_CURRENT_SOURCE_DIR}/l610
)

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)