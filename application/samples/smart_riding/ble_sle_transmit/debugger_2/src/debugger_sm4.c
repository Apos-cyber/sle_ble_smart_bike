#include "securec.h"
#include "osal_task.h"
#include "osal_event.h"
#include "osal_debug.h"
#include "app_init.h"
#include "soc_osal.h"
#include "osal_semaphore.h"
#include <errcode.h>
#include "watchdog.h"
#include "watchdog_porting.h"
#include "common_def.h"
#include "upg_porting.h"
#include "systick.h"
#include "nv.h"
#include "nv_common_cfg.h"
#include "sle_device_discovery.h"
#include <sm4.h>
#include "debugger_sm4.h"

#include "my_uart.h"

// SM4 密钥 - 用于测试
uint8_t sm4_key[SM4_BLOCK_SIZE] = {
    0x00, 0x11, 0x22, 0x33,
    0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xaa, 0xbb,
    0xcc, 0xdd, 0xee, 0xff
};

// 初始化向量
uint8_t iv[SM4_BLOCK_SIZE] = {0};

/**
 * 打印数组数据
 */
void print_array_data(const char* label, const uint8_t* data, size_t data_length)
{
    if (data == NULL || data_length == 0)
    {
        osal_printk("Invalid data pointer or zero length\r\n");
        return;
    }
    
    osal_printk("%s (length: %d):\r\n", label, data_length);
    osal_printk("Data: ");
    for (size_t i = 0; i < data_length; i++)
    {
        osal_printk("0x%02x,", data[i]);
        if ((i + 1) % 16 == 0) {
            osal_printk("\r\n       ");
        }
    }
    osal_printk("\r\n");
}

/**
 * 加密 uint8_t 数组数据
 * @param input_data 输入数据
 * @param input_len 输入数据长度
 * @param iv 初始化向量
 * @param output_buffer 输出缓冲区
 * @return 加密后数据长度，0表示失败
 */
uint8_t encrypt_uint8_array(const uint8_t* input_data, uint8_t input_len, 
                         uint8_t* iv, uint8_t* output_buffer)
{
    if (input_data == NULL || input_len == 0 || iv == NULL || output_buffer == NULL)
    {
        osal_printk("Encrypt: Invalid input parameters\r\n");
        return 0;
    }
    
    // 1. 复制原始数据到输出缓冲区
    memcpy_s(output_buffer, input_len, input_data, input_len);
    
    osal_printk("===Encryp process ===\r\n");
    print_array_data("Original data", input_data, input_len);
    
    // 2. 计算填充长度
    uint8_t padding_length = input_len % SM4_BLOCK_SIZE;
    if (padding_length != 0)
    {
        padding_length = SM4_BLOCK_SIZE - padding_length;
    }
    
    // 3. 执行填充
    for (size_t i = input_len; i < input_len + padding_length; i++)
    {
        output_buffer[i] = 0x00; // 填充0
    }
    
    uint8_t total_length = input_len + padding_length;
    
    // 4. 在数据末尾追加密钥作为校验
    memcpy_s(&output_buffer[total_length], SM4_BLOCK_SIZE, sm4_key, SM4_BLOCK_SIZE);
    total_length += SM4_BLOCK_SIZE;
    
    // 5. 计算块数
    size_t block_count = total_length / SM4_BLOCK_SIZE;
    
    // 6. 设置SM4加密密钥并执行加密
    SM4_KEY key_struct;
    sm4_set_encrypt_key(&key_struct, sm4_key);
    sm4_cbc_encrypt(&key_struct, iv, output_buffer, block_count, output_buffer);
    
    osal_printk("Encrypt cmpleted!\r\n");
    print_array_data("encrypt Data", output_buffer, total_length);
    
    return total_length;
}

/**
 * 解密 uint8_t 数组数据
 * @param iv 初始化向量
 * @param encrypted_data 加密数据
 * @param encrypted_len 加密数据长度
 * @param decrypted_buffer 解密输出缓冲区
 * @return 解密后数据长度，0表示失败
 */
uint8_t decrypt_uint8_array(uint8_t* iv, const uint8_t* encrypted_data, 
                         uint8_t encrypted_len, uint8_t* decrypted_buffer)
{
    if (encrypted_data == NULL || encrypted_len == 0 || iv == NULL || decrypted_buffer == NULL)
    {
        osal_printk("Decrypt: Invalid input parameters\r\n");
        return 0;
    }
    
    // 1. 检查数据长度是否是块大小的整数倍
    if (encrypted_len % SM4_BLOCK_SIZE != 0)
    {
        osal_printk("Decrypt: Data length not multiple of block size\r\n");
        return 0;
    }
    
    // 2. 计算块数
    size_t block_count = encrypted_len / SM4_BLOCK_SIZE;
    
    // 3. 设置SM4解密密钥并执行解密
    SM4_KEY key_struct;
    sm4_set_decrypt_key(&key_struct, sm4_key);
    sm4_cbc_decrypt(&key_struct, iv, encrypted_data, block_count, decrypted_buffer);
    
    osal_printk("=== Decrypt process ===\r\n");
    // print_array_data("before decrypt Data", encrypted_data, encrypted_len);
    
    // 4. 检查解密数据的最后16字节是否与密钥匹配
    if (memcmp(&decrypted_buffer[encrypted_len - SM4_BLOCK_SIZE], sm4_key, SM4_BLOCK_SIZE) == 0)
    {
        // 校验成功，返回去掉密钥校验块的长度
        uint8_t valid_data_length = encrypted_len - SM4_BLOCK_SIZE;
        
        osal_printk("Decrypt Pass! Verification Pass!\r\n");
        print_array_data("Decrypt Data", decrypted_buffer, valid_data_length);
        return valid_data_length;
    }
    else
    {
        osal_printk("Decrypt failed! Verification not matched\r\n");
        return 0;
    }
}


int sm4_en_de_data(uint8_t *data, uint8_t data_len)
{

    osal_printk("=== SM4 Encrypt and Decrypt Test Start ===\r\n");

    uint8_t encrypted_buffer[256] = {0};
    
    // 执行加密
    uint8_t encrypted_len = encrypt_uint8_array(data, data_len, iv, encrypted_buffer);
    
    if (encrypted_len == 0)
    {
        osal_printk("Encrypt failed!\r\n");
        return ENCRYPT_ERROR;
    }
    
    // 准备解密
    
    uint8_t decrypted_buffer[256] = {0};
    
    // 执行解密
    uint8_t decrypted_len = decrypt_uint8_array(iv, encrypted_buffer, encrypted_len, decrypted_buffer);
    if(decrypted_len <= 0)
    {
        osal_printk("Decrypt failed!\r\n");
        return DECRYPT_ERROR;
    }
    else
    {
        // 验证解密是否正确
        if (memcmp(data, decrypted_buffer, data_len) == 0)
        {
            osal_printk("SM4 Encrypt and Decrypt Test Success! Data consistency verified!\r\n");

            osal_printk("Original data: ");
            for (uint8_t i = 0; i < data_len; i++)
            {
                osal_printk("%c", data[i]);
            }
            osal_printk("\r\n");
            
            osal_printk("Decrypt data: ");
            for (uint8_t i = 0; i < decrypted_len; i++)
            {
                osal_printk("%c", decrypted_buffer[i]);
            }
            osal_printk("\r\n");

            memcpy_s(g_rx_buffer, decrypted_len, decrypted_buffer, decrypted_len);//这里将密文解密之后赋值给g_rx_buffer接下来进行数据格式检验！！！

            return SM4_ver_ok;
        }
        else
        {
            osal_printk("Decrypt failed or data inconsistent!\r\n");
            return ERROR;
        }
    }

}