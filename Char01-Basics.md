# 第一章: PowerCLI基础知识
***
VMware PowerCLI是一个基于Windows PowerShell的命令行和脚本工具，提供了超过700个cmdlet，用于管理和自动化vSphere、vCloud Director、vRealize Operations Manager、vSAN、NSX-T、VMware Cloud Services、AWS上的VMware Cloud、VMware HCX、VMware Site Recovery Manager、VMware Horizon环境。   
   
## 1. Powershell 基本语法
学习PowerCLI之前,我们先学习一下Powershell的基本语法.   
   
### 1.1 
   

### 1.2
   

### 1.3 
   

### 1.4 
   

## 2. PowerCLI 基本概念
   

## 3. 安装PowerCLI
### 3.0 安装前提条件


### 3.1 在线安装
#### 3.1.1 在线安装
打开Powershell(Windows直接打开Powershell终端,Linux和Mac OS需要先安装Powershell,然后在终端中输入pwsh,),然后输入如下命令:  
```
Install-Module VMware.PowerCLI
```   
按照提示操作就能安装成功.
   

### 3.2 离线安装
实际上就是将PowerCLI的模块压缩包解压到Powershell的Modules文件夹下面;   
#### 3.2.1 Windows下powershell 的Modules文件夹可能存在的位置为:   
```
C:\Program Files\WindowsPowerShell\Modules     (需要管理员权限并且所有用户生效)
或者
%UserProfile%\Documents\WindowsPowerShell\Modules   (仅当前用户生效)
```   
   
#### 3.2.2 Linux下
将下载的PowerCLI模块包解压到系统的如下位置:   
``` 
# MAC OS 和Linux OS一样
/usr/local/microsoft/powershell/7/Modules       (所有用户生效)
/<current user>/.local/share/powershell/Modules     (仅当前用户生效)

```   

### 3.3 老版本PowerCLI的安装

## 4. PowerCLI配置
### 4.1 设置Powershell的执行策略为不受限制
如果Powershell是运行在windows 平台上,则需要运行如下命令来设置PS脚本执行策略.(Mac 和Linux OS不需要此操作)   
```
Set-ExecutionPolicy unrestricted 
或者
Set-ExecutionPolicy RemoteSigned
```   

### 4.2 消除证书错误以及验证安装是否成功
在打开的powershell中输入如下命令来消除证书的错误;当然更安全的办法是让powershell信任vcenter或者Esxi的证书,但是实际情况是,由于信任证书操作需要额外的时间,我们一般忽略这个错误直接连接vCenter或者Esxi开始工作.(如果有人对信任证书有兴趣)
```
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore
```   
这条命令如果可以执行成功,则表示powercli以及安装成功,下面就可以正常使用了.



