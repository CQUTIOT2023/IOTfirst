import serial
import time
import struct

# UART配置
UART_PORT = '/dev/ttyS4'  # 请根据实际设备修改
BAUDRATE = 230400
TIMEOUT = 1  # 超时1秒

# 初始化串口
uart_A = serial.Serial(UART_PORT, BAUDRATE, timeout=TIMEOUT)

# 串口命令发送函数
def uart_sendCmd(cmd):
    uart_A.write(cmd)

# 将frameData中的字节转换为字符
def frame_data_to_str(frameData):
    # 转换为字符，如果字节超出可打印范围，则输出其十六进制表示
        return ' '.join(f"0x{byte:02X}" for byte in frameData)


# 主循环
rawData = b''

# 发送初始化命令
uart_sendCmd(b"AT+DISP=4\r")
uart_sendCmd(b"AT+BINN=2\r")
uart_sendCmd(b"AT+FPS=10\r")


        
