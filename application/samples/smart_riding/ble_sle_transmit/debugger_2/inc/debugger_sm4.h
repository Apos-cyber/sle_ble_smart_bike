#ifndef DEBUGGER_SM4_H
#define DEBUGGER_SM4_H


#define SM4_ver_ok      0
#define ENCRYPT_ERROR -1
#define DECRYPT_ERROR -2
#define ERROR -3


/**
 * 打印数组数据
 */
void print_array_data(const char* label, const uint8_t* data, size_t data_length);

/**
 * 加密 uint8_t 数组数据
 * @param input_data 输入数据
 * @param input_len 输入数据长度
 * @param iv 初始化向量
 * @param output_buffer 输出缓冲区
 * @return 加密后数据长度，0表示失败
 */
uint8_t encrypt_uint8_array(const uint8_t* input_data, uint8_t input_len, 
                         uint8_t* iv, uint8_t* output_buffer);


/**
 * 解密 uint8_t 数组数据
 * @param iv 初始化向量
 * @param encrypted_data 加密数据
 * @param encrypted_len 加密数据长度
 * @param decrypted_buffer 解密输出缓冲区
 * @return 解密后数据长度，0表示失败
 */
uint8_t decrypt_uint8_array(uint8_t* iv, const uint8_t* encrypted_data, 
                         uint8_t encrypted_len, uint8_t* decrypted_buffer);



/** 
 * 先加密后解密测试 
 */
int sm4_en_de_data(uint8_t *data, uint8_t data_len);

#endif  