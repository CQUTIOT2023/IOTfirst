#include <iostream>
#include <opencv2/opencv.hpp>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <vector>
#include <netinet/tcp.h>  // for TCP_NODELAY

#define PORT 8080  // 服务端端口
#define BUFFER_SIZE 3612  // 数据缓冲区大小

int main() {

    int server_fd, client_socket;
    struct sockaddr_in address;
    int addrlen = sizeof(address);

    // 创建套接字
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("Socket failed");
        exit(EXIT_FAILURE);
    }

    // 设置地址和端口
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    // 绑定套接字
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        exit(EXIT_FAILURE);
    }

    // 监听连接
    if (listen(server_fd, 3) < 0) {
        perror("Listen failed");
        exit(EXIT_FAILURE);
    }

    
    std::cout << "Waiting for connection on port " << PORT << "..." << std::endl;

    // 接受客户端连接
    if ((client_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t *)&addrlen)) < 0) {
        perror("Accept failed");
        exit(EXIT_FAILURE);
    }

    int flag = 1;
    setsockopt(client_socket, IPPROTO_TCP, TCP_NODELAY, &flag, sizeof(int));

    std::cout << "Client connected!" << std::endl;

    // 打开摄像头
    cv::VideoCapture cap;
    cap.open(0);
    if (!cap.isOpened()) {
        std::cerr << "Failed to open camera" << std::endl;
        close(client_socket);
        close(server_fd);
        return -1;
    }

    // 为了减少内存分配和数据拷贝，使用一个固定大小的缓冲区
    std::vector<uchar> buffer(BUFFER_SIZE);

    while (true) {
        cv::Mat frame;
        cap >> frame;  // 捕获一帧图像
        std::vector<uchar> img_buffer;
        img_buffer.reserve(frame.cols * frame.rows * frame.channels());
        //使用了reverse预留空间，避免数据拷贝
        // 编码为JPEG格式
        std::vector<int> params;
        params.push_back(cv::IMWRITE_JPEG_QUALITY);
        params.push_back(40);
        cv::imencode(".jpg", frame, img_buffer);
        
        // 发送图像大小
        uint32_t image_size = img_buffer.size();

       if(send(client_socket, &image_size, sizeof(image_size), 0) <0)
       {
           std::cerr << "Failed to send image size" << std::endl;
           break;
       }
        // 发送图像数据
        send(client_socket, img_buffer.data(), img_buffer.size(), 0);
        std::cout << "Sent image of size " << image_size << " bytes" << std::endl;
    }

    // 关闭套接字和摄像头
    cap.release();
    close(client_socket);
    close(server_fd);

    return 0;
}
