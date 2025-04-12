import socket
import serial
import struct
import time

# UART配置
UART_PORT = '/dev/ttyS4'  # 根据实际设备修改
BAUDRATE = 115200
TIMEOUT = 1  # 超时1秒

# TCP配置
TCP_IP = '0.0.0.0'  # 监听所有IP
TCP_PORT = 8082
BACKLOG = 1  # 最大连接数

# 帧缓冲限制
MAX_BUFFER_SIZE = 32 * 1024 * 1024  # 最大32MB的缓冲区
MAX_FRAME_SIZE = 4 * 1024 * 1024  # 假设单帧最大4MB
MAX_FPS = 15  # 调低帧率以提高稳定性
FRAME_INTERVAL = 1 / MAX_FPS  # 每帧间隔时间

# 初始化串口
uart_A = serial.Serial(UART_PORT, BAUDRATE, timeout=TIMEOUT)

# 发送串口初始化命令
def uart_sendCmd(cmd):
    uart_A.write(cmd)

# 串口初始化
def initialize_uart():
    uart_sendCmd(b"AT+DISP=4\r")
    print("UART initialized with commands: AT+DISP=4")

# 解包帧数据
def decode_frame(rawData, max_buffer_size=MAX_BUFFER_SIZE):
    FRAME_HEAD = b"\x00\xFF"
    FRAME_TAIL = b"\xDD"

    # 防止 rawData 缓冲区过大
    if len(rawData) > max_buffer_size:
        rawData = rawData[-max_buffer_size:]

    idx = rawData.find(FRAME_HEAD)
    if idx < 0:
        return None, rawData  # 没有找到帧头

    rawData = rawData[idx:]
    if len(rawData) < 6:  # 确保长度足够读取包长
        return None, rawData

    dataLen = struct.unpack("H", rawData[2:4])[0]
    frameLen = len(FRAME_HEAD) + 2 + dataLen + 2
    frameDataLen = dataLen - 16

    if len(rawData) < frameLen:
        return None, rawData  # 数据不完整，继续等待

    # 提取帧数据
    frame = rawData[:frameLen]
    rawData = rawData[frameLen:]

    frameTail = frame[-1]
    checksum = frame[-2]

    # 校验尾标志和校验和
    if frameTail != 0xDD or checksum != sum(frame[:-2]) % 256:
        return None, rawData  # 校验失败，丢弃当前帧

    resR = struct.unpack("B", frame[14:15])[0]
    resC = struct.unpack("B", frame[15:16])[0]
    res = (resR, resC)

    # 提取帧数据
    frameData = [struct.unpack("B", frame[20 + i:21 + i])[0] for i in range(0, frameDataLen)]
    
    return (frame, res), rawData  # 返回整个帧数据和剩余的未处理数据

# 主程序
def main():
    # 1. 初始化UART
    initialize_uart()

    # 2. 启动TCP服务端
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 3*1024 * 1024)  # 设置发送缓冲区
    server_socket.bind((TCP_IP, TCP_PORT))
    server_socket.listen(BACKLOG)
    print(f"Server listening on {TCP_IP}:{TCP_PORT}")

    # 3. 等待客户端连接
    client_socket, client_addr = server_socket.accept()
    print(f"Client connected from {client_addr}")

    rawData = b''
    last_send_time = 0

    try:
        # 主循环：读取串口数据并发送到客户端
        while True:
            if uart_A.in_waiting > 0:
                rawData += uart_A.read(min(uart_A.in_waiting, 1024))

                # 解包数据
                frame, rawData = decode_frame(rawData)

                if frame is not None:
                    frame_bytes = frame[0]  # 获取完整的帧数据

                    # 控制发送速率
                    current_time = time.time()
                    if current_time - last_send_time >= FRAME_INTERVAL:
                        try:
                            client_socket.sendall(frame_bytes)  # 发送完整的帧数据
                            last_send_time = current_time
                            print(f"Sent frame data to client. Resolution: {frame[1]}")
                        except Exception as e:
                            print(f"Error sending data: {e}")
    except KeyboardInterrupt:
        print("Server shutting down...")
    finally:
        client_socket.close()
        server_socket.close()
        uart_A.close()

if __name__ == "__main__":
    main()
