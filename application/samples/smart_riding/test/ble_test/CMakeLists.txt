if(DEFINED CONFIG_SAMPLE_SUPPORT_BLE_TEST)
    set(SOURCES_LIST
        ${CMAKE_CURRENT_SOURCE_DIR}/ble_test.c
        ${CMAKE_CURRENT_SOURCE_DIR}/ble_test_gatt.c
        ${CMAKE_CURRENT_SOURCE_DIR}/ble_test_adv.c
    )
else()
    set(SOURCES_LIST "")
endif()

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
