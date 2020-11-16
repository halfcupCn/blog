# [faceswap](https://github.com/deepfakes/faceswap)安装问题记录
现在各种深度学习框架满天飞，机器学习、人工智能的人才供不应求，我们虽然是移动客户端开发，也要紧跟潮流，尝试下新东西。这次我本来选择的是reddit的deepfake，因为之前有看过它的效果非常不错，而且操作也比较人性化，但是仔细一搜就发现作者因为怕造成不好的影响，已经不再开放使用了，所以我就顺手使用了github搜索deepfake推荐的这个faceswap项目，因为项目在不断开发，所以特别说明，记录的安装问题只针对faceswap_installer_v2.0.0版本。

## 初次安装
根据项目中的[安装教程](https://forum.faceswap.dev/viewtopic.php?f=4&t=20)，理论上只需要下载installer直接安装，接着等待即可。


1min、2min、10min、30min过去了，安装器还是在loading，实在等得不耐烦了，看了一眼输出日志，确实是在下载的，只能说公司网络不太行，希望大家比我更有耐心一些。最后等了不知道多久，终于完成了安装。


启动看看效果呢，双击启动器，闪过一个cmd弹框，然后显示start failed，让我们检查日志。打开日志，直接定位到python堆栈，有一句明显的提示：`tensorflow version=2.3.0 is not support, max support is 2.2.0`，这个应该是我之前熟悉tf的时候安装的tf版本太高了导致的，直接`pip install --upgrade tensorflow==2.2.0`把tf降级就可以了。
等待降级完成，继续启动，这次就可以正常启动了，接下来按照教程进行训练就可以啦。

## 二次安装
训练的时候总感觉有点慢，后来检查了一下启动时的cmd弹框，发现是使用的cpu模式，明明花了大价钱买的老黄家显卡，不用上不是浪费了，让我看看怎么调整设置，改成gpu模式。


翻了翻之前的[论坛文档](https://forum.faceswap.dev/viewtopic.php?f=4&t=20)和github的[安装文档](https://github.com/deepfakes/faceswap/blob/master/INSTALL.md)，找到了实际上的配置文件，就是安装目录下的/config/.faceswap文件，打开一看，只有一句`{"backend": "cpu"}`，看来这就是设置成cpu模式的原因了，直接修改为`{"backend": "nvidia"}`切换回nvidia模式，重新启动！


好，启动没问题，继续训练。诶，突然发现不能训练了，提示`failed to get device attribute 13 for device 0: CUDA_ERROR_UNKNOWN: unknown error`，嗯？！，这是什么东西？一番搜索之后，发现原来是tf-gpu模式需要cuda软件，这个错误是没有找到cuda，那么安装器似乎没有按照说明的那样给我们安装上这个软件呢，那么为了一劳永逸，干脆从头检查一遍需要安装哪些东西吧。
### 需要安装软件
- git
- python3.8
- MiniConda3 
- cuda 10.1
- cuDNN 7.6
从github文档、论坛文档和tf官方文档综合来看，需要的就是这些了，至于具体的python库文件，直接用`pip`按照需要安装项目中的`requirements-***`文件即可。


~~安装cuDNN居然还必须注册Nvidia家的账号，然后填一份巨长的调查表！简直反人类！~~


安装完成之后，继续启动！不出意外的还是不行，提示`cuDNN7_x64.h not found`，什么鬼，我明明按照tf官网的要求安装了cuDNN。搜了一圈之后没有找到类似的信息，那就只能去看源码了。理了一下逻辑之后，发现启动的时候会读取环境变量中`cuda`的安装路径，然后在**它的安装路径**中去找cuDNN文件，那么问题就在这里，不能把cuDNN单独安装，得直接复制文件到cuda的安装目录中。


复制完成，继续启动，这次终于完美启动了，开始训练，快了好多呀，从原来的1bit/s到了7bit/s了，足足快了7倍！