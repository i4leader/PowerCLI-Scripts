# 第三章: 管理虚拟机
***
## 查看虚拟机
```
Get-VM -Name VM
Get-VM -Name "My VM"
```   
如果虚拟机的名称重点有空格,那必须在虚拟机的名称前后加上双引号.

## 虚拟机开关机
虚拟机开机
```
Start-VM -VM VM -Confirm -RunAsync
```

虚拟机关机
```
Stop-VM -VM VM -Confirm -RunAsync
```

虚拟机重启
```
Restart-VM -VM VM -RunAsync -Confirm
```

## 迁移虚拟机

## 批量从模板创建虚拟机

## 批量更改虚拟机设置

## 查看虚拟机详细信息
此命令将为您提供有关VM的详细信息，例如名称，CPU数量，操作系统，Service Pack级别
```
Get-VM |Where {$_.PowerState -eq “PoweredOn“} |Sort Name |Select Name, NumCPU, @{N=“OSHAL“;E={(Get-WmiObject -ComputerName $_.Name-Query “SELECT * FROM Win32_PnPEntity where ClassGuid = ‘{4D36E966-E325-11CE-BFC1-08002BE10318}’“ |Select Name).Name}}, @{N=“OperatingSystem“;E={(Get-WmiObject -ComputerName $_ -Class Win32_OperatingSystem |Select Caption).Caption}}, @{N=“ServicePack“;E={(Get-WmiObject -ComputerName $_ -Class Win32_OperatingSystem |Select CSDVersion).CSDVersion}}
```

### 查看所有带有SCSI Bus Sharing磁盘的虚拟机
```
# 创建数组来存放虚拟机
$array = @()

# 变量$vm存放集群中所有虚拟机
$vms = get-cluster “ClusterName” | get-vm
#循环来找存在BusSharing模式的磁盘Loop for BusSharingMode
foreach ($vm in $vms)
   {
   # 找出Physical 磁盘或者BusSharingMode的磁盘
   $disks = $vm | Get-ScsiController | Where-Object {$_.BusSharingMode -eq ‘Physical’ -or $_.BusSharingMode -eq ‘Virtual’}
   #循环来将找到的每个Physical磁盘以及bus sharing磁盘以及其虚拟机信息等,写入数组
   foreach ($disk in $disks)
      {
      $REPORT = New-Object -TypeName PSObject
      $REPORT | Add-Member -type NoteProperty -name Name -Value $vm.Name
      $REPORT | Add-Member -type NoteProperty -name VMHost -Value $vm.Host
      $REPORT | Add-Member -type NoteProperty -name Mode -Value $disk.BusSharingMode
      $REPORT | Add-Member -type NoteProperty -name Type -Value “BusSharing”
      $array += $REPORT
      }
}
#显示数组中的内容
$array
```

### 查看所有带了USB外设的虚拟机

```
Get-View -ViewType VirtualMachine -Property Name,'Config.Hardware' | Where-Object { $_.Config.Hardware.Device.Where({$_.gettype().name -match 'VirtualUSBController'}) } | Select-Object -ExpandProperty Name
```

### 查看所有RDM虚拟机
```
Get-VM | Get-HardDisk | Where-Object {$_.DiskType -like “Raw*”} | Select @{N=”VMName”;E={$_.Parent}},Name,DiskType,@{N=”LUN_ID”;E={$_.ScsiCanonicalName}},@{N=”VML_ID”;E={$_.DeviceName}},Filename,CapacityGB
```

### 查看所有Multi-Writer虚拟机
```
#创建数组
$array = @()
$vms = get-cluster “ClusterName” | get-vm
foreach ($vm in $vms)
   {
   $disks = get-advancedsetting -Entity $vm | ? { $_.Value -like “*multi-writer*”  }
      foreach ($disk in $disks){
      $REPORT = New-Object -TypeName PSObject
      $REPORT | Add-Member -type NoteProperty -name Name -Value $vm.Name
      $REPORT | Add-Member -type NoteProperty -name VMHost -Value $vm.Host
      $REPORT | Add-Member -type NoteProperty -name Mode -Value $disk.Name
      $REPORT | Add-Member -type NoteProperty -name Type -Value “MultiWriter”
      $array += $REPORT
      }
   }
$array
```

### 查看虚拟机所有外设
```
Get-View -ViewType VirtualMachine | %{
     $vm = $_
     $_.Config.Hardware.Device | Select @{N="VM name";E={$vm.Name}},@{N="HW name";E={$_.GetType().Name}},@{N="Label";E={$_.DeviceInfo.Label}}
}
```


### 启动虚拟机Changed Block Tracking(CBT)
更改块跟踪（CBT）是VMware中的一项技术，用于将所有更改的数据记录在VMDK文件中，以便当备份软件运行增量备份时，它确切地知道发生了什么更改，并且只能将差异发送给备份软件。通过仅移动更改的数据，这项技术可以极大地提高备份速度和效率。随着许多备份软件永久迁移到增量过程，更改块跟踪是备份的一项启用技术。

大多数软件都可以在单个VM上启用CBT，但是，如果您正处于实施新备份软件或虚拟部署的开始阶段，则可能需要在整个服务器场中主动启用CBT。在某些情况下，您的某些VM禁用了CBT，您只需要为这些VM启用它即可。而根据VMware KB https://kb.vmware.com/s/article/1031873 对每台没有启用CBT的虚拟机做更改非常耗时,而使用PowerCLI来实现这个更改会非常方便,并且还不需要重启,大大节省了时间,该脚本可用于在整个vCenter中所有的虚拟机启用CBT，该脚本将检查禁用了CBT的VM，然后执行重新配置VM，创建快照和删除快照来启用CBT功能。

#### 查看没有启用CBT的虚拟机列表
```
 Get-VM | Select Name, @{N="CBT";E={(Get-View $_).Config.ChangeTrackingEnabled}} | WHERE {$_.CBT -like "False"}
```
#### 启用或者禁用单个虚拟机的CBT
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

#### 批量启用CBT
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

#### 批量禁用CBT
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

## 一行命令删除所有挂了CD-ROM的虚拟机
### 方法一
1. 查看所有连接了CDROM的虚拟机
```
Get-VM | Where-Object {$_.PowerState –eq “PoweredOn”} | Get-CDDrive | FT Parent, IsoPath
```

2. 设置所有CD-ROM为空
```
Get-VM | Where-Object {$_.PowerState –eq “PoweredOn”} | Get-CDDrive | Set-CDDrive -NoMedia -Confirm:$False
```

### 方法二
1. 查看所有连接了CDROM的虚拟机
```
Get-VM | where {($_ | Get-CDDrive).ISOPath -ne $null}  |FT Name, @{Label="ISO file"; Expression = { ($_ | Get-CDDrive).ISOPath }}
```

2. 设置所有CD-ROM连接状态为断开
```
Get-VM | Get-CDDrive | Where {$_.ConnectionState.Connected} | Set-CDDrive -Connected $false -Confirm:$false
```

**注意:对于某些正在使用CDROM内文件的虚拟机,运行该命令会报错**

## 查看新创建的虚拟机
```
Get-VIEvent -maxsamples 10000 | Where {$_.Gettype().Name -eq “VmCreatedEvent”} | Select createdTime, UserName, FullFormattedMessage
```

## 查看刚删除的虚拟机
```
Get-VIEvent -maxsamples 10000 | Where {$_.Gettype().Name -eq “VmRemovedEvent”} | Select createdTime, UserName, FullFormattedMessage
```

## 查看无效的不可访问的虚拟机
```
Get-View -ViewType VirtualMachine | Where {-not $_.Config.Template} | Where{$_.Runtime.ConnectionState -eq “invalid” -or $_.Runtime.ConnectionState -eq “inaccessible”} | Select Name
```

## 列出上个礼拜vCenter上的error告警
```
Get-VIEvent -maxsamples 10000 -Type Error -Start $date.AddDays(-7) | Select createdTime, fullFormattedMessage
```


## 查看所有没有安装VMware Tools的虚拟机
```
Get-View -ViewType “VirtualMachine” -Property Guest,name -filter @{“Guest.ToolsStatus”=”toolsNotInstalled”;”Guest.GuestState”=”running”} | Select Name
```

## 列出所有设置了内存预留的虚拟机
```
Get-VM | Get-VMResourceConfiguration | Where {$_.MemReservationMB -ne 0} | Select VM,MemReservationMB
```

## 列出所有设置了CPU预留的虚拟机
```
Get-VM | Get-VMResourceConfiguration | Where {$_.CpuReservationMhz -ne 0} | Select VM,CpuReservationMhz
```

## 列出所有关机状态的虚拟机
```
Get-VM | where {$_.powerstate -eq "PoweredOff"} | Sort-Object | get-harddisk | ft parent, capacityGB, Filename -autosize
```

## 列出所有开机状态的虚拟机
```
Get-VM | where {$_.powerstate -eq "PoweredOn"} | Sort-Object | get-harddisk | ft parent, capacityGB, Filename -autosize
```

## 列出所有虚拟机以及他们的磁盘大小
此命令获取虚拟机的列表，并显示每个磁盘路径，容量和可用空间
```
ForEach ($VM in Get-VM ){($VM.Extensiondata.Guest.Disk | Select @{N="Name";E={$VM.Name}},DiskPath, @{N="Capacity(MB)";E={[math]::Round($_.Capacity/ 1MB)}}, @{N="Free Space(MB)";E={[math]::Round($_.FreeSpace / 1MB)}}, @{N="Free Space %";E={[math]::Round(((100* ($_.FreeSpace))/ ($_.Capacity)),0)}})}
```

## 升级VMware Tools
```
$vm = Get-VM -Name app01a
Update-Tools -VM $vm
```
注意: Update-Tools 自动升级VMware Tools这个命令需要虚拟机能访问互联网