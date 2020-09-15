# 第三章: 管理虚拟机
***
## 查看虚拟机
```
Get-VM -Name VM
Get-VM -Name "My VM"
```   
如果虚拟机的名称重点有空格,那必须在虚拟机的名称前后加上双引号.

### 查看所有共享磁盘的虚拟机


### 查看所有带了USB外设的虚拟机

### 查看所有带了所有有GPU的虚拟机



## 虚拟机开关机

## 迁移虚拟机

## 批量从模板创建虚拟机

## 批量升级虚拟机VMware Tools

## 批量更改虚拟机设置

### 启动虚拟机Chain Block Tracking(CBT)
 
### 

## 一行命令删除所有挂了CD-ROM的虚拟机


## 升级VMware Tools
```
$vm = Get-VM -Name app01a
Update-Tools -VM $vm
```
注意: Update-Tools 自动升级VMware Tools这个命令需要虚拟机能访问互联网