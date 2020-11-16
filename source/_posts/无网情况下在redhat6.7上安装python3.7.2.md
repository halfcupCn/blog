# 内网环境下在Redhat6.7上编译安装Python3.7.2

>因为业务需求，需要在内网环境下部署一套系统，开发时使用的是Python 3.7.2，而老Redhat上只有2.6.6，对Python有了解的都知道Python的版本割裂情况很严重，所以很明显不能使用自带的Python，而需要重新安装。
>
>这里的下载操作都是在一台联网的机器上进行的，再通过scp/sftp传输给内网机器
>
>编译操作是在内网机器上进行的，建议分步进行，以便查找问题


## 安装
### 下载源码
从[官网链接](https://www.python.org/downloads/release/python-372/)下载对应平台的源码，redhat使用[tar包](https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tgz)即可。

```bash
wget https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tgz
tar -xf Python-3.7.2.tgz
cd Python-3.7.2
```

### 开始编译
```bash
sudo ./configure --enable-optimizations
sudo make
sudo make install
```
试运行项目，提示openssl版本过低，1.0.2以上的才支持ssl/2，那么接下来要做的就是编译一个高版本的openssl。

#### 编译openssl
找到openssl的[官网下载页面](https://www.openssl.org/source/old/1.1.1/)，选择一个比较新的版本(1.1.1)的openssl源码来[下载](https://www.openssl.org/source/old/1.1.1/openssl-1.1.1.tar.gz)，接着按照官网的说明来进行编译和安装。
```bash
wget https://www.openssl.org/source/old/1.1.1/openssl-1.1.1.tar.gz
tar -xf openssl-1.1.1.tar.gz
cd openssl-1.1.1.tar.gz
./config
sudo make -j4
sudo make install
```
这样openssl的编译和安装就完成了。接下来按照上面的步骤重新编译python。

继续试运行项目之后，提示`ImportError: No module named 'sqlite3'`，使用`find / -name *sqlite3*`之后发现是能找到sqlite3命令的，猜测可能是原来带的版本太低，导致无法使用，接下来更新sqlite3的版本

#### 更新sqlite3
找到sqlite的官网[下载页面](https://sqlite.org/download.html)，下载[源码](https://sqlite.org/2020/sqlite-autoconf-3330000.tar.gz)进行编译安装
```bash
wget https://sqlite.org/2020/sqlite-autoconf-3330000.tar.gz
tar -xf sqlite-autoconf-3330000.tar.gz
cd sqlite-autoconf-3330000
./configure
sudo make -j4
sudo make insatll
```

完成之后重新编译python，此时需要启用python的加载sqlite配置

```bash
sudo ./configure --enable-optimizations --enable-loadable-sqlite-extensions
```
之后正常`make & install`

继续测试项目，此时可以正常运行。

### 配置后台运行
因为项目使用`django`框架，所以采用`nohup`命令来实现后台运行

- 启动https的服务
```bash
# 把服务运行在8866端口上，将日志输出到了项目路径下的/log/dist_plat.log文件中
# 同时指定https证书
nohup python3 manage.py runserver_plus --cert server.crt 0.0.0.0:8866 >> ./log/dist_plat.log 2>&1 &
```

- 启动http的服务
```bash
# 把服务运行在8866端口上，将日志输出到了项目路径下的/log/dist_plat.log文件中
nohup python3 manage.py runserver 0.0.0.0:8866 >> ./log/dist_plat.log  2&>1 &
```

>如果不需要指定日志输出，可以去掉重定向后面的命令，末尾的&不能去掉

- 关闭服务
```bash
# 获取当前服务运行的进程号
ps -aux|grep manage.py| grep -v grep | awk '{print $2}'
# 关闭服务对应的进程
kill -9 {process}
```

### 更新项目文件
```bash
git fetch
git pull
```