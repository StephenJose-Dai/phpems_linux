在部署phpems之前，你需要先安装docker和docker compose，各类操作系统如何安装docker请参考官方文档 https://docs.docker.com/engine/install/

<img width="2623" height="1331" alt="QQ_1772262235174" src="https://github.com/user-attachments/assets/53f4b589-0c05-48a7-99cd-4d9deb300b66" />

按照官方文档来安装docker的话，通常docker compose都会一并安装掉
docker安装完成后再来执行下列操作

目前支持在线和离线来部署phpems docker版，请根据具体情况和需求来选择



### 一、在线安装
#### 1、到 https://github.com/StephenJose-Dai/phpems_linux/releases 下载最新的 ```phpems11_installl.sh``` 文件

##### 2、给脚本赋权并执行
```
chmod +x phpems11_installl.sh
./phpems11_installl.sh
```

#### 接着回车，等待检测完毕后，会询问你要选择在线pull还是离线包导入，选择1，最后按照窗口提示一步一步执行即可.

#### 3、安装完毕后，窗口会显示访问地址、用户名密码等信息，该信息仅显示一次，记得妥善保存。


### 二、离线安装

#### 1、到 https://github.com/StephenJose-Dai/phpems_linux/releases 下载最新的 ```phpems11_installl.sh``` 、 ```docker-compose.yml``` 和 ```phpems_linux_11.tar.gz```

#### 2、解压 ```phpems_linux_11.tar.gz```

```
tar -zxvf phpems_linux_11.tar.gz
```

##### 3、给脚本赋权并执行
```
chmod +x phpems11_installl.sh
./phpems11_installl.sh
```

#### 接着回车，等待检测完毕后，会询问你要选择在线pull还是离线包导入，选择2，最后按照窗口提示一步一步执行即.

#### 4、安装完毕后，窗口会显示访问地址、用户名密码等信息，该信息仅显示一次，记得妥善保存。


# 支援
如果有部署问题或者其他问题，可以联系作者支援  

![戴戴的Linux](qrcode.jpg)  ![phpems技术交流群](qqqrc.jpg)  
