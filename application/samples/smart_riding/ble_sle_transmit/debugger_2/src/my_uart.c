#include "common_def.h"
#include "osal_debug.h"
#include "soc_osal.h"
#include "gpio.h"
#include "error.h"
#include "uart.h"
#include "pinctrl.h"

#include "string.h"
#include "my_uart.h"
// #include "debugger_sm4.h"
#include "main.h"

uint8_t g_rx_buffer[MAX_BUFFER_SIZE];
// uint8_t rx_buffer[16];
uint8_t receive_flag=0;
uint8_t mac_num =0;

// uart_buffer_config_t g_buffer_config=
// {
//     .rx_buffer = rx_buffer,
//     .rx_buffer_size = 16
// };

/**
 * @brief �µĴ��ڽ��ջص����� - ֧������ƴ��
 * @param buffer ���յ�������
 * @param length ���ݳ���
 * @param error �����־
 */
/**
 * @brief �µĴ��ڽ��ջص����� - �򵥿ɿ�������ƴ��
 * @param buffer ���յ�������
 * @param length ���ݳ���
 * @param error �����־
 */

static uint16_t current_index = 0;  // ��ǰд��λ��

void uart_rx_callback(const void *buffer, uint16_t length, bool error)
{
    unused(error);
    
    // ��黺�����Ƿ��㹻
    if (current_index + length >= MAX_BUFFER_SIZE) {
        current_index = 0;
        memset(g_rx_buffer,0,sizeof(g_rx_buffer));
        osal_printk("[UART] Buffer full! Reset\n");
        // osal_printk("current_index:%d,length:%d,MAX_BUFFER_SIZE:%d\r\n",current_index,length,MAX_BUFFER_SIZE);
    }

    // osal_printk("buffer:%s\r\n",buffer);

    // �������ݵ�ȫ�ֻ�����
    memcpy(g_rx_buffer + current_index, buffer, length);
    current_index += length;
    // osal_printk("[debug]current_index:%d,length:%d!!!!!!!!!!!!!!\r\n",current_index,length);
    
    // ȷ���ַ�����null��β
    g_rx_buffer[current_index] = '\0';

    
    // ����Ƿ��յ��������ݣ�������������Ի��з������������Ը�����Ҫ�޸ģ�
    if (length > 0 && ((const uint8_t *)buffer)[length - 1] == '}') {
        osal_printk("[UART] Current buffer content: %s\nTotal received: %d bytes\n", g_rx_buffer, current_index);
        
        if(receive_flag)//����û�����꼴�̷���
            return;
        
        // sm4_en_de_data(g_rx_buffer,length);//�ӽ������ݲ���
        
        char target[]="{\"asking_tag\":[\"";//{"asking_tag":["AA:BB:CC:DD:EE:FF","..."]}
        char *p=strstr((char *)g_rx_buffer,target);
        if(p==NULL)
        {
            receive_flag=0;
            osal_printk("No find ,target:%s\r\n",target);//���� 
        }
        else//������asking_tag��:�Ŀ�ͷ��ַ
        {
            receive_flag=1;
            osal_printk("find!!!!\r\n");//����
        }

        osal_printk("[debug] new_receive_flag:%d\r\n",receive_flag);
        if(receive_flag==0)/*�ȴ�������������ɺ�����������������⴦���б����������ݡ�
                            �׶ˣ��ᶪ�����ڴ���ʱ���ܵ�������*/
        memset(g_rx_buffer,0,MAX_BUFFER_SIZE);

            // ���ﲻ���� current_index���ȴ��������������������
        current_index=0;
    }
}

// void uart_rx_callback(const void *buffer, uint16_t length, bool error)//����app�·���json��ʽ{"asking_tag":"ABABABAB"}
// {
//     unused(error);
//     unused(buffer);

//     osal_printk("uart_receive:%s,length:%d,[debug] receive_flag:%d\r\n",g_rx_buffer,length,receive_flag);
//     if(receive_flag)//����û�����꼴�̷���
//         return;
    
//     // sm4_en_de_data(g_rx_buffer,length);//�ӽ������ݲ���
    
//     // char target[]="{\"asking_tag\":[\"";//{"asking_tag":["AA:BB:CC:DD:EE:FF","..."]}
//     // char *p=strstr((char *)g_rx_buffer,target);
//     // if(p==NULL)
//     // {
//     //     receive_flag=0;
//     //     osal_printk("No find ,target:%s\r\n",target);//���� 
//     // }
//     // else//������asking_tag��:�Ŀ�ͷ��ַ
//     // {
//     //     receive_flag=1;
//     //     osal_printk("find!!!!\r\n");//����
//     // }

//     // osal_printk("[debug] new_receive_flag:%d\r\n",receive_flag);

//     // if(receive_flag==0)/*�ȴ�������������ɺ�����������������⴦���б����������ݡ�
//     //                     �׶ˣ��ᶪ�����ڴ���ʱ���ܵ�������*/
//     //     memset(g_rx_buffer,0,MAX_BUFFER_SIZE);
// }

// static uint8_t get_num(uint8_t num)
// {
//     return num-'/';
// }

bool save_MAC()
{
    //{"asking_tag":           14λ
    // char target[]={'{','"','a','s','k','i','n','g','_','t','a','g','"',':','"'};
    char target[]="{\"asking_tag\":[\"";//�����ı�����Ӽ��//{"asking_tag":["AA:BB:CC:DD:EE:FF","..."]}

    uint8_t trans_arr[25]={0};//��1��ʼ

    char *p=strstr((char *)g_rx_buffer,target);//һ�����ҵ����ǵý��а�ȫ�Գ��ȼ��
    uint8_t buff_len=(uint8_t)strlen((char *)g_rx_buffer);

    //����Ƿ����㹻�ĳ���
    if(buff_len<(uint8_t)(strlen(target)+12+5))
    {
        osal_printk("Error:buff_len=%d,target_len=%d\r\n",buff_len,strlen(target));
        return false;
    }
    //����"AA:BB:CC:DD:EE:FF","..."�������ж���mac��ַ
    osal_printk("buff_len:%u\r\n",buff_len);
    mac_num=(uint8_t)((buff_len-14-2)/(12+5+2));//ʡ�Զ�����ɵ�Ӱ��
    for(uint8_t j=0;j<mac_num;j++)
    {
        // uint8_t json_mac_local;
        uint8_t save_local;
        for(int i=16+j*20;i<16+12+5+j*20;i=i+3)
        {
            // json_mac_local=i;
            save_local=i-15-j*20;//��1��ʼ
            if(p[i]>='0'&&p[i]<='9')
            {
                trans_arr[save_local]=p[i]-'0';
            }
            else if(p[i]>='A'&&p[i]<='F')
            {
                trans_arr[save_local]=p[i]-'A'+10;
            }
            else
            {
                osal_printk("Error char:%c\r\n",p[i]);
                return false;
            }
            if(p[i+1]>='0'&&p[i+1]<='9')
            {
                trans_arr[save_local+1]=p[i+1]-'0';
            }
            else if(p[i+1]>='A'&&p[i+1]<='F')
            {
                trans_arr[save_local+1]=p[i+1]-'A'+10;
            }
            else
            {
                osal_printk("Error char:%c\r\n",p[i+1]);
                return false;
            }
            // osal_printk("[debug] p[%d]:%c,trans_arr[%d]:%d\r\n",i,p[i],save_local,trans_arr[save_local]);
            // osal_printk("[debug] p[%d]:%c,trans_arr[%d]:%d\r\n",i+1,p[i+1],save_local+1,trans_arr[save_local+1]);
        }
        uint8_t k=0;

        for(int i=1;i<=18;i=i+3)
        {
            g_send_mac[j][k]=trans_arr[i]<<4|trans_arr[i+1];//��4λ����4λ���4λ���Ϳ���ʮ�����Ƶ���λ���ϲ�
            osal_printk("[debug]save_mac[%d][%d]:%02x\r\n",j,k,g_send_mac[j][k]);
            k++;
        }
        // g_send_mac[0]=1;
        memset(trans_arr,0,20);
    }
    return true;
}

errcode_t uart_init(void)
{
    // uapi_pin_set_mode(UART_TXD_PIN, (pin_mode_t)UART_PIN_MODE);
    // uapi_pin_set_mode(UART_RXD_PIN, (pin_mode_t)UART_PIN_MODE);

    // uart_attr_t attr = {
    //     .baud_rate = UART_BAUDRATE,
    //     .data_bits = UART_DATA_BIT_8,
    //     .stop_bits = UART_STOP_BIT_1,
    //     .parity = UART_PARITY_NONE
    // };
     
    // uart_pin_config_t pin_config = {
    //     .tx_pin = UART_TXD_PIN,
    //     .rx_pin = UART_RXD_PIN,
    //     .cts_pin = PIN_NONE,
    //     .rts_pin = PIN_NONE
    // };

    // uapi_uart_deinit(UART_BUS_ID);
    // errcode_t ret = uapi_uart_init(UART_BUS_ID, &pin_config, &attr, NULL, &g_buffer_config);
    // if (ret != ERRCODE_SUCC) {
    //     osal_printk("UART init failed: 0x%x\r\n", ret);
    //     return ret;
    // }

    errcode_t ret = uapi_uart_register_rx_callback(UART_BUS_ID, UART_RX_CONDITION_FULL_OR_IDLE, 
                                        1, uart_rx_callback);
    if (ret != ERRCODE_SUCC) {
        osal_printk("Register callback failed: 0x%x\r\n", ret);
        return ret;
    }

    return ERRCODE_SUCC;
}