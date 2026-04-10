add_subdirectory_if_exist(src)

set(SOURCES "${SOURCES}" PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}"
    "${CMAKE_CURRENT_SOURCE_DIR}/inc"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../gnss/common"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../gnss/gnss"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../gnss/l610"
    PARENT_SCOPE)
