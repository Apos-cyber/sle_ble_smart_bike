#include "pinctrl.h"
#include "i2c.h"
#include "soc_osal.h"
#include "app_init.h"

#define MPU6050_I2C_ADDR 0x68
#define MPU6050_SAMPLE_RATE_MS 500

/* MPU6050 Registers */
#define MPU6050_REG_PWR_MGMT_1 0x6B
#define MPU6050_REG_ACCEL_XOUT_H 0x3B
#define MPU6050_REG_ACCEL_XOUT_L 0x3C
#define MPU6050_REG_ACCEL_YOUT_H 0x3D
#define MPU6050_REG_ACCEL_YOUT_L 0x3E
#define MPU6050_REG_ACCEL_ZOUT_H 0x3F
#define MPU6050_REG_ACCEL_ZOUT_L 0x40
#define MPU6050_REG_GYRO_XOUT_H 0x43
#define MPU6050_REG_GYRO_XOUT_L 0x44
#define MPU6050_REG_GYRO_YOUT_H 0x45
#define MPU6050_REG_GYRO_YOUT_L 0x46
#define MPU6050_REG_GYRO_ZOUT_H 0x47
#define MPU6050_REG_GYRO_ZOUT_L 0x48
#define MPU6050_REG_WHO_AM_I 0x75

#define MPU6050_TASK_PRIO 24
#define MPU6050_TASK_STACK_SIZE 0x1000

#define MPU6050_I2C_BUS_ID 0
#define MPU6050_I2C_SCL_PIN 25
#define MPU6050_I2C_SDA_PIN 26
#define MPU6050_I2C_SCL_PIN_MODE 26
#define MPU6050_I2C_SDA_PIN_MODE 27
#define MPU6050_I2C_BAUDRATE 100000

static i2c_data_t g_i2c_data = {0};
static uint8_t g_tx_buff[2] = {0};
static uint8_t g_rx_buff[14] = {0};

static void app_mpu6050_pin_init(void)
{
    uapi_pin_set_mode(MPU6050_I2C_SCL_PIN, MPU6050_I2C_SCL_PIN_MODE);
    uapi_pin_set_mode(MPU6050_I2C_SDA_PIN, MPU6050_I2C_SDA_PIN_MODE);
#if defined(CONFIG_PINCTRL_SUPPORT_IE)
    uapi_pin_set_ie(MPU6050_I2C_SDA_PIN, PIN_IE_1);
#endif
}

static int app_mpu6050_write_reg(uint8_t reg_addr, uint8_t data)
{
    g_tx_buff[0] = reg_addr;
    g_tx_buff[1] = data;
    g_i2c_data.send_buf = g_tx_buff;
    g_i2c_data.send_len = 2;
    g_i2c_data.receive_buf = NULL;
    g_i2c_data.receive_len = 0;

    return uapi_i2c_master_write(MPU6050_I2C_BUS_ID, MPU6050_I2C_ADDR, &g_i2c_data);
}

static int app_mpu6050_read_regs(uint8_t reg_addr, uint8_t len)
{
    g_tx_buff[0] = reg_addr;
    g_i2c_data.send_buf = g_tx_buff;
    g_i2c_data.send_len = 1;
    g_i2c_data.receive_buf = g_rx_buff;
    g_i2c_data.receive_len = len;

    return uapi_i2c_master_writeread(MPU6050_I2C_BUS_ID, MPU6050_I2C_ADDR, &g_i2c_data);
}

static int app_mpu6050_init(void)
{
    int ret;
    uint8_t who_am_i = 0;

    ret = app_mpu6050_read_regs(MPU6050_REG_WHO_AM_I, 1);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[MPU6050] Failed to read WHO_AM_I\r\n");
        return ret;
    }

    who_am_i = g_rx_buff[0];
    osal_printk("[MPU6050] WHO_AM_I: 0x%02X\r\n", who_am_i);

    if (who_am_i != 0x68) {
        osal_printk("[MPU6050] Device not found!\r\n");
        return ERRCODE_FAIL;
    }

    ret = app_mpu6050_write_reg(MPU6050_REG_PWR_MGMT_1, 0x00);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[MPU6050] Failed to wake up sensor\r\n");
        return ret;
    }

    osal_printk("[MPU6050] Init success!\r\n");
    return ERRCODE_SUCC;
}

static void app_mpu6050_read_data(void)
{
    int ret;
    int16_t acc_x, acc_y, acc_z;
    int16_t gyro_x, gyro_y, gyro_z;

    ret = app_mpu6050_read_regs(MPU6050_REG_ACCEL_XOUT_H, 14);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[MPU6050] Failed to read sensor data\r\n");
        return;
    }

    acc_x = (int16_t)((g_rx_buff[0] << 8) | g_rx_buff[1]);
    acc_y = (int16_t)((g_rx_buff[2] << 8) | g_rx_buff[3]);
    acc_z = (int16_t)((g_rx_buff[4] << 8) | g_rx_buff[5]);

    gyro_x = (int16_t)((g_rx_buff[8] << 8) | g_rx_buff[9]);
    gyro_y = (int16_t)((g_rx_buff[10] << 8) | g_rx_buff[11]);
    gyro_z = (int16_t)((g_rx_buff[12] << 8) | g_rx_buff[13]);

    osal_printk("[MPU6050] Accel: X=%d, Y=%d, Z=%d | Gyro: X=%d, Y=%d, Z=%d\r\n", acc_x, acc_y, acc_z, gyro_x, gyro_y,
                gyro_z);
}

static void *mpu6050_task(const char *arg)
{
    unused(arg);

    app_mpu6050_pin_init();
    int ret = uapi_i2c_master_init(MPU6050_I2C_BUS_ID, MPU6050_I2C_BAUDRATE, 0);
    osal_printk("[MPU6050] I2C init ret=0x%x\r\n", ret);

    if (app_mpu6050_init() != ERRCODE_SUCC) {
        osal_printk("[MPU6050] Init failed!\r\n");
        return NULL;
    }

    while (1) {
        osal_msleep(MPU6050_SAMPLE_RATE_MS);
        app_mpu6050_read_data();
    }

    return NULL;
}

static void mpu6050_entry(void)
{
    osal_task *task_handle = NULL;

    osal_kthread_lock();
    task_handle = osal_kthread_create((osal_kthread_handler)mpu6050_task, 0, "Mpu6050Task", MPU6050_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, MPU6050_TASK_PRIO);
    }
    osal_kthread_unlock();
}

app_run(mpu6050_entry);
