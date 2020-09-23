# 第四章: 主机配置
***
本章中很多命令都需要PowerCLI已经连接到vCenter上才能运行正确.

## 给esxi主机分配许可
您可以使用Set-VMHost cmdlet的LicenseKey参数为vCenter Server系统上的主机设置许可证密钥。
```
$vmhost = Get-VMHost -Name Host
Set-VMHost -VMHost $vmhost -LicenseKey 00000-00000-00000-00000-00000
```

## 查看Esxi主机
```
Get-VMhost
```

## Esxi

## 列出所有主机的时间
```
get-vmhost | select Name,@{Name="Time";Expression={(get-view $_.ExtensionData.configManager.DateTimeSystem).QueryDateTime()}}
```   

## 列出主机上跑的虚拟机数量
```
Get-VMHost | Select @{N="Cluster";E={Get-Cluster -VMHost $_}}, Name, @{N="NumVM";E={($_ | Get-VM).Count}} | Sort Cluster, Name
```

## 列出主机硬件信息
这对于您要管理的主机硬件很有用。该命令将显示硬件供应商，CPU类型，内核数量，CPU插槽数量，CPU速度和内存大小
```
Get-VMHost |Sort Name |Get-View |Select Name, @{N=“Type“;E={$_.Hardware.SystemInfo.Vendor+ “ “ + $_.Hardware.SystemInfo.Model}},@{N=“CPU“;E={“PROC:“ + $_.Hardware.CpuInfo.NumCpuPackages + “ CORES:“ + $_.Hardware.CpuInfo.NumCpuCores + “ MHZ: “ + [math]::round($_.Hardware.CpuInfo.Hz / 1000000, 0)}},@{N=“MEM“;E={“” + [math]::round($_.Hardware.MemorySize / 1GB, 0) + “ GB“}}
```

## 查询主机管理网络
这对于查看主机映射了哪些网络很有用。
```
Get-VMHost | Get-VMHostNetwork | Select Hostname, VMKernelGateway -ExpandProperty VirtualNic | Where {$_.ManagementTrafficEnabled} | Select Hostname, PortGroupName, IP, SubnetMask
```

## 查询主机vMotion网路
这对于查看主机映射了哪些vMotion网络很有用。
```
Get-VMHost | Get-VMHostNetwork | Select Hostname, VMKernelGateway -ExpandProperty VirtualNic | Where {$_.vMotionEnabled} | Select Hostname, PortGroupName, IP, SubnetMask
```

## 列出主机存储多路径策略

```
Get-VMHost | Get-ScsiLun | Select VMHost, ConsoleDeviceName, Vendor, MultipathPolicy
```

## 查询主机DRS状态
列出主机DRS状态的快速命令–如果需要，可以针对多个主机运行。
```
Get-VMHost | Get-Cluster | Select Name, DrsEnabled, DrsMode, DrsAutomationLevel
```

## 检查主机HA状态,级别
此命令将检查ESX主机或群集上的高可用性状态
```
Get-VMHost | Get-Cluster | Select Name, HAFailoverLevel, HARestartPriority, HAIsolationResponse
```

## 获取ESX主机名，IP，子网，网关和DNS配置
```
Get-VMGuestNetworkInterface –VM VMNAME | Select VM, IP, SubnetMask, DefaultGateway, Dns
```

## 获取Esxi主机的NTP配置
```
Get-VMHost | Sort Name | Select Name, @{N=”NTP”;E={Get-VMHostNtpServer $_}}
```

## 获取硬件服务器的服务识别码Service Tag
```
Get-VMHost | Get-View | foreach {$_.Summary.Hardware.OtherIdentifyingInfo[3].IdentifierValue}
```

## 获取ESXI主机名称和硬件服务器的服务识别码Service Tag
```
Get-VMHost | Get-View | Select Name, @{N=”Service Tag”;E={$_.Summary.Hardware.OtherIdentifyingInfo[3].IdentifierValue}}
```

## 获取主机的BIOS版本以及BIOS版本发布时间
在规划基础架构上的固件更新时可以使用如下命令来查看
```
Get-View -ViewType HostSystem | Sort Name | Select Name,@{N="BIOS version";E={$_.Hardware.BiosInfo.BiosVersion}}, @{N="BIOS date";E={$_.Hardware.BiosInfo.releaseDate}}
```

## 获取主机的syslog设置
```
get-vmhost | Get-VMHostAdvancedConfiguration -Name Syslog.global.logHost
```


# 主机配置文件管理
***
## 创建主机配置文件New-VMHostProfile
```
$cluster = Get-Cluster “Cluster-A”
$host = Get-VMHost “esxi01.example.local” 
$profile = New-VMHostProfile –Name TestProfile – ReferenceHost $host
```

## 附上主机配置文件Apply-VMHostProfile –AssociateOnly


## 测试主机配置文件Test-VMHostProfileCompliance


## 应用主机配置文件Apply-VMHostProfile –ApplyOnly