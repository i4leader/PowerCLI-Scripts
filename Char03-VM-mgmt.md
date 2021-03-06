# 第三章: 使用 PowerCLI 管理虚拟机
***

#  一. 虚拟机基本管理
## 1.1 查看虚拟机
```
Get-VM -Name VM
Get-VM -Name "My VM"
```   
* 注意:如果虚拟机的名称重点有空格,那必须在虚拟机的名称前后加上双引号.

## 1.2 虚拟机开关机
* 虚拟机开机
```
Start-VM -VM VM -Confirm:$False -RunAsync
```

* 虚拟机关机
```
Stop-VM -VM VM -Confirm:$false -RunAsync
```

* 虚拟机重启
```
Restart-VM -VM VM -RunAsync -Confirm:$false
```

* 批量开启虚拟机电源
```
Get-VM Ubuntu-VM* | Start-VM -Confirm:$false -RunAsync
```
注意: ***-confirm:$false*** 命令表示不需要人工干预确认; ***-RunAsync*** 表示命令会同步执行多个开机任务
![](images/c3/start-vm.png)


## 1.3 迁移虚拟机
### a.迁移虚拟机到不同的主机
```
 Get-VM -Name Ubuntu-VM1 | Move-VM -Destination 10.186.67.146
```
![](images/c3/Move-VM.png)

### b.迁移虚拟机到不同的存储
```
 Get-VM -Name Ubuntu-VM1 | Move-VM -Datastore "local-0 (2)" 
```
![](images/c3/Move-VM-datastore.png)

### c.迁移虚拟机到文件夹
* 首先创建一个虚拟机文件夹
```
$dc =  Get-Datacenter -Name vSAN-DC
$vmFolder = Get-View -id $dc.ExtensionData.VmFolder
$vmFolder.CreateFolder("UbuntuTestFolder")
```
![](Images/c3/CreateVMFolder.png)

* 迁移虚拟机到文件夹
```
$vmobject = Get-VM -Name Ubuntu*
Move-VM -VM $vmObject -InventoryLocation  (($vmObject | Get-Datacenter) | Get-Folder -Name "UbuntuTestFolder")
```
![](images/c3/move-vm-folder.png)

#### 参数说明:
* -InventoryLocation 在PowerCLI 6.3版本之前版本虚拟机迁移到文件夹可以使用-Folder参数，在该版本之后就改成了-InventoryLocation

## 1.4 批量从模板创建虚拟机
### a. 获取vCenter上所有虚拟机模板
```
get-template
```
![](images/c3/get-template.png)

### b. 打开集群HA和DRS
```
Set-Cluster -Cluster VSAN-Cluster -HAEnabled $True -DrsEnabled $True
```
![](images/c3/enablehadrs.png)

### c. 从模板创建虚拟机
脚本如下:
```
# 定义存储以及定义部署的主机
$DS = Get-Datastore -Name vsan*
$esxihost = Get-Cluster | Get-VMhost

# 指定虚拟机数量
$i = 1
while ($i -le 5)
{
$i
# 创建虚拟机并指定虚拟机名称和模板,还能指定CPU和内存,磁盘格式，以及网络
$VM = New-VM -Name "Ubuntu-VM$i” -Template "U-Temp” -Datastore $DS -DiskStorageFormat Thin -NetworkName "VM Network” -VMHost ($esxihost | Get-Random) | Set-VM -NumCpu 2 -MemoryGB 4 -Confirm:$false
$i++
}
```
![](images/c3/create-vm-from-teemplate.png)
接着使用 ***Get-VM*** 命令可以看到所有的虚拟机都创建好了.
![](images/c3/get-vm.png)

#### 参数说明：
* -DiskStorageFormat 该参数可以指定设置磁盘的置备方式，主要有三种，Thin，Thick， EagerZeroedThick

## 1.5 批量更改虚拟机设置
### a. 查看虚拟机高级设置
```
Get-VM -Name Ubuntu-VM1 | Get-AdvancedSetting
```
![](images/c3/Get-AdvancedSetting.png)

### b. 定义虚拟机列表
```
$VMs = Get-VM -Name Ubuntu-VM*
```

### c. 定义循环
```
foreach ($vm in $VMs)
```

### d. 定义具体设置的高级参数
```
{
   Get-VM -Name $vm | Get-AdvancedSetting  -Name tools.guest.desktop.autolock | Set-AdvancedSetting -value $TRUE
}
```
注意:设置的值必须为大写的TRUE或者FALSE.如果是小写是不生效的.

### e.以上脚本整合在一起就可以做批量的虚拟机高级设置的修改了
```
$VMs = Get-VM -Name Ubuntu-VM*
foreach ($vm in $VMs)
{
   Get-VM -Name $vm | Get-AdvancedSetting  -Name tools.guest.desktop.autolock | Set-AdvancedSetting -value $TRUE -Confirm:$FALSE
} 
```
![](images/c3/set-advancedsetting.png)

### f.最后使用命令查看刚才的虚拟机高级选项
```
Get-VM -Name Ubuntu-VM* | Get-AdvancedSetting -Name tools.guest.desktop.autolock
```
![](images/c3/get-vm-advancedsetting.png)

# 二. 实用命令
## 2.1 查看虚拟机详细信息
此命令将为您提供有关VM的详细信息，例如名称，电源状态，CPU数量，已分配内存，已分配磁盘空间，硬件版本，文件夹，所在Esxi主机
```
Get-VM | Select-Object Name, PowerState, Guest, NumCpu, MemoryGb, ProvisionedSpaceGB, HardwareVersion, Folder,VMHost | ft
```
![](images/c3/Get-VM-details.png)
#### 参数说明：
* Format-Table 可简写成ft，用来做表格状格式来输出
* 如果要看虚拟机的所有对象,可以使用 Select-Object * 先输出所有对象,再进行关键内容筛选

### 2.2 查看所有带有SCSI Bus Sharing磁盘的虚拟机
```
# 创建数组来存放虚拟机
$array = @()

# 变量$vm存放集群中所有虚拟机
$vms = get-cluster "ClusterName" | get-vm
#循环来找存在BusSharing模式的磁盘Loop for BusSharingMode
foreach ($vm in $vms)
   {
   # 找出Physical 磁盘或者BusSharingMode的磁盘
   $disks = $vm | Get-ScsiController | Where-Object {$_.BusSharingMode -eq 'Physical' -or $_.BusSharingMode -eq 'Virtual'}
   #循环来将找到的每个Physical,Virtual的bus sharing磁盘以及其虚拟机信息等,写入数组
   foreach ($disk in $disks)
      {
      $REPORT = New-Object -TypeName PSObject
      $REPORT | Add-Member -type NoteProperty -name Name -Value $vm.Name
      $REPORT | Add-Member -type NoteProperty -name VMHost -Value $vm.VMHost
      $REPORT | Add-Member -type NoteProperty -name Mode -Value $disk.BusSharingMode
      $REPORT | Add-Member -type NoteProperty -name Type -Value "BusSharing"
      $array += $REPORT
      }
}
#显示数组中的内容
$array
```
![](images/c3/bus-sharing.png)

#### 参数说明:
* @() 表示新建了一个空的数组
* New-Object 表示新建一个对象
* Add-Member 对这个对象新增属性
* $array += $REPORT 表示向数组中新增一条对象

### 2.3 查看所有带了USB外设的虚拟机

```
Get-VM | Get-USBDevice
```

### 2.4 查看所有RDM虚拟机
```
Get-VM | Get-HardDisk | Where-Object {$_.DiskType -like "Raw*"} | Select @{N=”VMName”;E={$_.Parent}},Name,DiskType,@{N=”LUN_ID”;E={$_.ScsiCanonicalName}},@{N=”VML_ID”;E={$_.DeviceName}},Filename,CapacityGB
```

### 2.5 查看所有Multi-Writer虚拟机
```
#创建数组
$array = @()
$vms = get-cluster "ClusterName” | get-vm
foreach ($vm in $vms)
   {
   $disks = get-advancedsetting -Entity $vm | ? { $_.Value -like "*multi-writer*”  }
      foreach ($disk in $disks){
      $REPORT = New-Object -TypeName PSObject
      $REPORT | Add-Member -type NoteProperty -name Name -Value $vm.Name
      $REPORT | Add-Member -type NoteProperty -name VMHost -Value $vm.VMHost
      $REPORT | Add-Member -type NoteProperty -name Mode -Value $disk.Name
      $REPORT | Add-Member -type NoteProperty -name Type -Value "MultiWriter"
      $array += $REPORT
      }
   }
$array
```

### 2.6 查看虚拟机所有外设
```
Get-View -ViewType VirtualMachine | %{
     $vm = $_
     $_.Config.Hardware.Device | Select @{N="VM name";E={$vm.Name}},@{N="HW name";E={$_.GetType().Name}},@{N="Label";E={$_.DeviceInfo.Label}}
}
```


### 2.7 启动虚拟机Changed Block Tracking(CBT)
更改块跟踪（CBT）是VMware中的一项技术，用于将所有更改的数据记录在VMDK文件中，以便当备份软件运行增量备份时，它确切地知道发生了什么更改，并且只能将差异发送给备份软件。通过仅移动更改的数据，这项技术可以极大地提高备份速度和效率。随着许多备份软件永久迁移到增量过程，更改块跟踪是备份的一项启用技术。

大多数软件都可以在单个VM上启用CBT，但是，如果您正处于实施新备份软件或虚拟部署的开始阶段，则可能需要在整个服务器场中主动启用CBT。在某些情况下，您的某些VM禁用了CBT，您只需要为这些VM启用它即可。而根据VMware KB https://kb.vmware.com/s/article/1031873 对每台没有启用CBT的虚拟机做更改非常耗时,而使用PowerCLI来实现这个更改会非常方便,并且还不需要重启,大大节省了时间,该脚本可用于在整个vCenter中所有的虚拟机启用CBT，该脚本将检查禁用了CBT的VM，然后执行重新配置VM，创建快照和删除快照来启用CBT功能。

#### a. 查看没有启用CBT的虚拟机列表
```
 Get-VM | Select Name, @{N="CBT";E={(Get-View $_).Config.ChangeTrackingEnabled}} | WHERE {$_.CBT -like "False"}
```
#### b. 启用或者禁用单个虚拟机的CBT
```
    $vm="VM_Name"
     
    $vmtest = Get-vm $vm| get-view
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
     
    #禁用 ctk
    $vmConfigSpec.changeTrackingEnabled = $false
    $vmtest.reconfigVM($vmConfigSpec)
    $snap=New-Snapshot $vm -Name "Disable CBT"
    $snap | Remove-Snapshot -confirm:$false
     
    #启用 ctk
    $vmConfigSpec.changeTrackingEnabled = $true
    $vmtest.reconfigVM($vmConfigSpec)
    $snap=New-Snapshot $vm -Name "Enable CBT"
    $snap | Remove-Snapshot -confirm:$false
```

#### c. 批量启用CBT
```
$targets = Get-VM | Select Name, @{N="CBT";E={(Get-View $_).Config.ChangeTrackingEnabled}} | WHERE {$_.CBT -like "False"}
ForEach ($target in $targets) {
   $vm = $target.Name
   Get-VM $vm | Get-Snapshot | Remove-Snapshot -confirm:$false
   $vmView = Get-vm $vm | get-view
   $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
   $vmConfigSpec.changeTrackingEnabled = $true
   $vmView.reconfigVM($vmConfigSpec)
   New-Snapshot -VM (Get-VM $vm ) -Name "CBTSnap"
   Get-VM $vm | Get-Snapshot -Name "CBTSnap" | Remove-Snapshot -confirm:$false
}
```

#### d. 批量禁用CBT
```
$targets = Get-VM | Select Name, @{N="CBT";E={(Get-View $_).Config.ChangeTrackingEnabled}} | WHERE {$_.CBT -like "True"}
ForEach ($target in $targets) {
   $vm = $target.Name
   Get-VM $vm | Get-Snapshot | Remove-Snapshot -confirm:$false
   $vmView = Get-vm $vm | get-view
   $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
   $vmConfigSpec.changeTrackingEnabled = $false
   $vmView.reconfigVM($vmConfigSpec)
   New-Snapshot -VM (Get-VM $vm ) -Name "Disable CBT"
   Get-VM $vm | Get-Snapshot -Name "Disable CBT" | Remove-Snapshot -confirm:$false
}
```

## 2.8 一行命令删除所有挂了CD-ROM的虚拟机
### 方法一
a. 查看所有连接了CDROM的虚拟机
```
Get-VM | Where-Object {$_.PowerState –eq "PoweredOn”} | Get-CDDrive | FT Parent, IsoPath
```
![](images/c3/check-iso.png)

b. 设置所有CD-ROM为空
```
Get-VM | Where-Object {$_.PowerState –eq "PoweredOn"} | Get-CDDrive | Set-CDDrive -NoMedia -Confirm:$False
```

### 方法二
a. 查看所有连接了CDROM的虚拟机
```
Get-VM | where {($_ | Get-CDDrive).ISOPath -ne $null}  |FT Name, @{Label="ISO file"; Expression = { ($_ | Get-CDDrive).ISOPath }}
```
![](images/c3/check-iso-2.png)

b. 设置所有CD-ROM连接状态为断开
```
Get-VM | Get-CDDrive | Where {$_.ConnectionState.Connected} | Set-CDDrive -Connected $false -Confirm:$false
```

**注意:对于某些正在使用CDROM内文件的虚拟机,运行该命令会报错**

## 2.9 查看新创建的虚拟机(包括模板部署的虚拟机以及克隆的虚拟机)
```
Get-VIEvent -maxsamples 10000 | Where {($_.FullFormattedMessage -like "*from template*") -or ($_.FullFormattedMessage -like "Created virtual machine*") -or ($_.FullFormattedMessage -like "Cloning*")} | Select createdTime, UserName, FullFormattedMessage
```
![](images/c3/get-vm-new-generated.png)
#### 参数说明:
* -maxsamples 获取的事件的最大数量
* -or powershell 逻辑运算符表示或者
* where 表示筛选事件的条件,和where-object用法一样

## 2.10 查看刚删除的虚拟机
```
Get-VIEvent -maxsamples 10000 | Where {$_.Gettype().Name -eq "VmRemovedEvent"} | Select createdTime, UserName, FullFormattedMessage
```
![](images/c3/get-deleted-vm.png)

## 2.11 查看无效的不可访问的虚拟机
```
Get-View -ViewType VirtualMachine | Where {-not $_.Config.Template} | Where{$_.Runtime.ConnectionState -eq "invalid” -or $_.Runtime.ConnectionState -eq "inaccessible”} | Select Name
```

## 2.12 列出上个礼拜vCenter上的error告警
```
Get-VIEvent -maxsamples 10000 -Type Error -Start (Get-Date).AddDays(-7) | Select createdTime, fullFormattedMessage
```
![](images/c3/get-error-events-7days-ago.png)

## 2.13 查看所有没有安装VMware Tools的虚拟机
```
Get-View -ViewType "VirtualMachine" -Property Guest,name -filter @{"Guest.ToolsStatus"="toolsNotInstalled";"Guest.GuestState"="running"} | Select Name
```
![](images/c3/VMTools-not-installed.png)

## 2.14 列出所有设置了内存预留的虚拟机
```
Get-VM | Get-VMResourceConfiguration | Where {$_.MemReservationMB -ne 0} | Select VM,MemReservationMB
```

## 2.15 列出所有设置了CPU预留的虚拟机
```
Get-VM | Get-VMResourceConfiguration | Where {$_.CpuReservationMhz -ne 0} | Select VM,CpuReservationMhz
```

## 2.16 列出所有关机状态的虚拟机
```
Get-VM | where {$_.powerstate -eq "PoweredOff"} | Sort-Object | get-harddisk | ft parent, capacityGB, Filename -autosize
```
![](images/c3/Shutdown-vms.png)

## 2.17 列出所有开机状态的虚拟机
```
Get-VM | where {$_.powerstate -eq "PoweredOn"} | Sort-Object | get-harddisk | ft parent, capacityGB, Filename -autosize
```

## 2.18 列出所有虚拟机以及他们的磁盘大小
此命令获取虚拟机的列表，并显示每个磁盘路径，容量和可用空间
```
Foreach ($VM in Get-VM )
{
   ($VM.Extensiondata.Guest.Disk | Select @{N="Name";E={$VM.Name}},DiskPath, @{N="Capacity(MB)";E={[math]::Round($_.Capacity/ 1MB)}}, @{N="Free Space(MB)";E={[math]::Round($_.FreeSpace / 1MB)}}, @{N="Free Space %";E={[math]::Round(((100* ($_.FreeSpace))/ ($_.Capacity)),0)}})
}
```
![](images/c3/get-vm-freespace.png)

#### 参数说明:
* @{N="", E={}} 自定义输出的语法格式,N=后面加名字,E=后面加返回值的表达式

## 2.19 升级VMware Tools
```
$vm = Get-VM -Name app01a
Update-Tools -VM $vm
```
* 注意: Update-Tools 自动升级VMware Tools这个命令需要虚拟机能访问互联网,并且仅支持 Windows OS

## 2.20 列出所有虚拟机配置的操作系统版本以及正在运行的操作系统版本
```
Get-VM | Sort | Get-View -Property @("Name", "Config.GuestFullName", "Guest.GuestFullName") | Select -Property Name, @{N="Configured OS";E={$_.Config.GuestFullName}},  @{N="Running OS";E={$_.Guest.GuestFullName}} | Format-Table -AutoSize
```
![](images/c3/Get-VM-OperatingSystem.png)

# 结语
本章我们学习了如何使用 PowerCLI 来做虚拟机的基本管理,并且还学习了很多生产环境中的实用查询以及实用技能.譬如虚拟机的 CBT 功能的开启,如果手动去开机实际上是非常花费时间的,学习了 PowerCLi 工具之后,您就可以一个脚本搞定几天也干不完的事情,是不是非常的值. 