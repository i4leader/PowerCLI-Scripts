# 第四章: PowerCLI 管理 Esxi主机配置-第一部分
***
本章中很多命令都需要PowerCLI已经连接到vCenter上才能运行正确.

## 给esxi主机分配许可
您可以使用Set-VMHost cmdlet的LicenseKey参数为vCenter Server系统上的主机设置许可证密钥。
```
$vmhost = Get-VMHost -Name Host
Set-VMHost -VMHost $vmhost -LicenseKey your-license-key
```

## 批量给主机分配许可
```
$vmhosts = Get-VMhost 
foreach ($vmhost in $vmhosts) {Set-VMHost -VMHost $vmhost -LicenseKey Your_license_key -Confirm:$False} 
```

新安装的环境需要初始化配置,这里我给大家演示如何批量做主机初始化的操作.我的环境规划如下,三台Esxi 主机,每台主机 6 块网卡,两块网卡做管理网络和 vMotion 网络,vminc0 和 vmnic1,两块网卡做存储网络vmnic2和 vmnic3,两块网卡做业务网络vmnic4 和 vmnic5.

## 批量设置主机 DNS ,NTP信息
对于新增的主机,我们需要设定他的 dns 以及时间服务器;如果主机数量较多,建议使用脚本方式批量修改
```
# 先定义 DNS 服务器
$dnspri = dns01.example.com
$dnsalt = dns02.example.com
 
# 指定域名地址
$domainname = example.com
 
# 指定 NTP 服务器地址
$ntpone =  ntp01.example.com
$ntptwo = ntp02.example.com

# 指定需要设置的主机,如下例子为vcenter 集群 ClusterA 下所有主机地址 
$esxHosts = Get-Cluster -Name ClusterA | Get-VMhost

# 循环语句设置每台机子的 dns 和 ntp 地址
foreach ($esx in $esxHosts) {
 
   Get-VMHostNetwork -VMHost $esx | Set-VMHostNetwork -DomainName $domainname -DNSAddress $dnspri , $dnsalt -Confirm:$false

   Add-VMHostNTPServer -NtpServer $ntpone , $ntptwo -VMHost $esx -Confirm:$false
 
   # 设置 ntp 服务为随主机启动
   Get-VMHostService -VMHost $esx | where{$_.Key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
 
   # 重启 ntp 服务
   Get-VMHostService -VMHost $esx | where{$_.Key -eq "ntpd"} | Restart-VMHostService -Confirm:$false
 
}
```
# 传统标准交换机设置
## 新建标准交换机
对于新安装的esxi 默认有一个标准交换机 vSwith0,默认情况下只有一个上联口,我们需要为这个交换机配置冗余上联口.
```
# 配置管理口上行链路冗余
Get-Cluster -Name ClusterA | Get-VMHost | Get-VirtualSwitch -Name vSwitch0 | Set-VirtualSwitch -Nic vmnic0,vmnic1 -Confirm:$false

# 新建存储使用的标准交换机,开启 Jumbo Frame
Get-Cluster -Name ClusterA | Get-VMHost | New-VirtualSwitch -Name vSwitch1 -Nic vmnic2,vmnic3 -Mtu 9000 -Confirm:$false

# 新建业务使用的标准交换机,开启 Jumbo Frame
Get-Cluster -Name ClusterA | Get-VMHost | New-VirtualSwitch -Name vSwitch1 -Nic vmnic4,vmnic5 -Mtu 9000 -Confirm:$false
```
找一台主机检查一下物理网卡配置以及标准交换机配置:
![](images/c4/PhysicalAdapter.png)
![](images/c4/StdvSwitch.png)
以上图可以看到所有主机都已经完成如上的配置.

## 批量设置 vMotion 网络
### 直接开启管理口的 vMotion 功能 
```
Get-Cluster -Name ClusterA | Get-VMHost | Get-VMHostNetworkAdapter -Name vmk0  |Set-VMHostNetworkAdapter -VMotionEnabled $true
```

### 新建 VMK 口来启用 vMotion
* 如下示例表示新建一个 dhcp 获取地址的 vmk1
```
Get-Cluster -Name ClusterA | Get-VMHost | New-VMHostNetworkAdapter -PortGroup vMotion -VirtualSwitch vSwitch0 
```
![](images/c4/dhcp-vmk1.png)

* 接着对这个 vmk1 开启 vMotion 功能
```
Get-Cluster -Name ClusterA | Get-VMHost | Get-VMHostNetworkAdapter -Name vmk1  |Set-VMHostNetworkAdapter -VMotionEnabled $true
```

如果要使用静态ip地址,需要使用如下命令来设置;由于每台主机的 ip 地址不一样,这里我们给出一条配置单台主机的示例,如果需要批量设置,可以使用循环的方法来处理,这个循环的方法,我们后续再做详细介绍.
```
Get-VMHost -Name <Host1> | New-VMHostNetworkAdapter -PortGroup vMotion -VirtualSwitch vSwitch0 -IP <ip address> -SubnetMask 255.255.255.0
```
### 参数说明:
* <Host1> 这里需要输入主机 ip 或者 FQDN

## 批量创建网络端口组
### 存储使用的网络端口组
由于条件限制,我这边给大家演示的是使用 powerCLI 去配置走 iSCSI 的存储.
一般来说存储网络我们都需要有多路径的设置,因此需要创建两个存储使用的 vmk 口连不同的上联口,然后做端口绑定
```
# 每台主机都需要创建两个 vmk 网口给 iSCSI 存储使用的,并且需要指定 IP 地址,下面为配置单台主机的例子,如果需要配置多个主机,这里需要使用powershell循环语法,循环语法需要您的主机地址是连续的,这个后续再做补充,请继续关注.
Get-VMHost -Name <Host1> | New-VMHostNetworkAdapter -PortGroup iSCSI01 -VirtualSwitch vSwitch1 -IP 10.100.10.1 -SubnetMask 255.255.255.0 -Mtu 9000
Get-VMHost -Name <Host1> | New-VMHostNetworkAdapter -PortGroup iSCSI02 -VirtualSwitch vSwitch1 -IP 10.100.10.2 -SubnetMask 255.255.255.0 -Mtu 9000
```
![](images/c4/New-ISCSI.png)

```
# 上面的命令设置了默认 VLAN 为 0,在生产环境中一般不会是 VLAN 0,所以我们需要使用下面的命令来修改 VLAN 号. 这个在上面的存储网络 vmk 配置好以后是可以批量设置的(当然如果上联交换机是 access 口不是 trunk 口,则不需要修改任何设置).
Get-Cluster -Name ClusterA | Get-VMHost | Get-VirtualPortGroup -Name "iSCSI01" | Set-VirtualPortGroup -Name "iSCSI01" -vlanid 16
Get-Cluster -Name ClusterA | Get-VMHost | Get-VirtualPortGroup -Name "iSCSI02" | Set-VirtualPortGroup -Name "iSCSI02" -vlanid 16
```
![](images/c4/set-vlan.png)

### 业务使用的网络端口组
```
$vmhosts = Get-Cluster -Name ClusterA | Get-VMHost
foreach($vmhost in $vmhosts)
{
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name VM-Network -VLanId 0
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name App-A -VLanId 1
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name App-B -VLanId 2
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name App-C -VLanId 3
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name Office-OA -VLanId 4
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name Storage-ISCSI -VLanId 16
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name DB-A -VLanId 5
}

```
![](images/c4/create-pg-vss.png)

## 分别指定存储网络端口组上行链路
* iSCSI01 上行链路 vmnic2
* iSCSI02 上行链路 vmnic3
```
Get-Cluster -Name ClusterA | Get-VMHost | Get-VirtualPortGroup -VirtualSwitch vswitch1 -Name ISCSI01 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive vmnic2 -MakeNicUnused vmnic3
Get-Cluster -Name ClusterA | Get-VMHost | Get-VirtualPortGroup -VirtualSwitch vswitch1 -Name ISCSI02 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive vmnic3 -MakeNicUnused vmnic2

```

## 批量启用主机软 iscsi 适配器
```
$vmhosts = Get-Cluster -Name ClusterA | Get-VMHost
foreach ($vmhost in $vmhosts) {
Get-VMHostStorage -VMHost $vmhost | Set-VMHostStorage -SoftwareIScsiEnabled $True
}
```
![](images/c4/enableiscsi.png)

## 存储网络端口绑定
查看 iSCSI HBA 卡,获取 HBA 卡名称
```
Get-Cluster -Name ClusterA | Get-VMHost | Get-VMHostHba
```
![](images/c4/vmhba65.png)

端口绑定
```
#  绑定 vmk2
Get-Cluster "ClusterA" | Get-VMHost |
ForEach-Object
    $esxcli = Get-EsxCli -V2 -VMHost $_
    $bind = @{
        adapter = 'vmhba65'
        force = $true
        nic = 'vmk2'
    }
    $esxcli.iscsi.networkportal.add.Invoke($bind)
}

# 绑定 vmk3
Get-Cluster "ClusterA" | Get-VMHost |
ForEach-Object
    $esxcli = Get-EsxCli -V2 -VMHost $_
    $bind = @{
        adapter = 'vmhba65'
        force = $true
        nic = 'vmk3'
    }
    $esxcli.iscsi.networkportal.add.Invoke($bind)
}
```
![](images/c4/portbinding.png)


## 根据存储配置最佳实践,设置 iSCSI 高级参数 DelayedAck 为 False
关于为什么要设置 DelayedAck 为 False,请参考 VMware KB https://kb.vmware.com/s/article/1002598
```
$VMHosts = Get-Cluster -Name ClusterA | Get-VMHost
Foreach ($vmhost in $VMHosts) {
$HostView = Get-VMHost $vmhost | Get-View
$HostStorageSystemID = $HostView.configmanager.StorageSystem
$HostiSCSISoftwareAdapterHBAID = ($HostView.config.storagedevice.HostBusAdapter | where {$_.Model -match "iSCSI Software"}).device
$options = New-Object VMWare.Vim.HostInternetScsiHbaParamValue[] (1)
$options[0] = New-Object VMware.Vim.HostInternetScsiHbaParamValue
$options[0].key = "DelayedAck"
$options[0].value = $false
$HostStorageSystem = Get-View -ID $HostStorageSystemID
$HostStorageSystem.UpdateInternetScsiAdvancedOptions($HostiSCSISoftwareAdapterHBAID, $null, $options)
}
```

## 批量添加 iSCSI 存储
```
Get-Cluster -Name ClusterA | Get-VMHost | Get-VMHostHba -Type iScsi | New-IScsiHbaTarget -Address <Target-IP-addr> -ChapType Preferred -ChapName <yourchapname> -ChapPassword <iscsipassword>
```
#### 参数说明:
* -Address 添加存储的目标 ip 地址(必须)
* -chapName 填写 chap 名称(可选)
* -ChapPassword 填写 Chap 密码(可选)

## 重新扫描 HBA 卡来识别存储
```
$vmhosts = Get-Cluster -Name ClusterA | Get-VMHost
foreach ($vmhost in $vmhosts) {
Get-VMHostStorage -VMHost $vmhost -RescanAllHba
Get-VMHostStorage -VMHost $vmhost -RescanVmfs
}
```
![](images/c4/rescan-hba-vmfs.png)

# 上面的脚本我们可以整合成一个
```
$VIUser="administrator@vSphere.local"
$VIPassword="password"

$dnspri = "dns01.example.com"
$dnsalt = "dns02.example.com"
$domainname = "example.com"
$ntpone =  "ntp01.example.com"
$ntptwo = "ntp02.example.com"
$iSCSI_Target = "10.0.0.1","10.0.0.2","10.0.0.3"
$VMHosts = Get-Datacenter Beijing-DC | Get-Cluster -Name ClusterA | Get-VMhost
$License = "XXXX-XXXX-XXXX-XXXX"
$vMotion_Net="10.10.10."
$vMotion_StartIP=200
$vMotion_NetMask="255.255.255.0"
$private:vMotion_StartIP
$iSCSI01_Net="192.168.101."
$iSCSI01_StartIP=1
$private:iSCSI01_StartIP
$iSCSI02_Net="192.168.101."
$iSCSI02_StartIP=101
$private:iSCSI02_StartIP
$iSCSI_NetMask="255.255.255.0"
$vMotion_vLAN = 1009
$iSCSI01_vLAN = 1010
$iSCSI02_vLAN = 1010

$options = New-Object VMWare.Vim.HostInternetScsiHbaParamValue[] (1)   
$options[0] = New-Object VMware.Vim.HostInternetScsiHbaParamValue
$options[0].key = "DelayedAck"
$options[0].value = $false


Connect-VIServer vcentre.localdomain.local -User $VIUser -Password $VIPassword

# 循环语句设置每台机子的 dns 和 ntp 地址
foreach ($vmhost in $VMHosts) {
    $iSCSI01_IP=$iSCSI01_Net+$iSCSI01_StartIP
    $iSCSI02_IP=$iSCSI02_Net+$iSCSI02_StartIP
    $vMotion_IP=$vMotion_Net+$vMotion_StartIP
    
    # 安装主机许可
    Set-VMHost -VMHost $vmhost -LicenseKey $License -Confirm:$False
    
    # 为主机配置 DNS
    Get-VMHostNetwork -VMHost $vmhost | Set-VMHostNetwork -DomainName $domainname -DNSAddress $dnspri ,$dnsalt -Confirm:$false
    
    # 为主机配置 NTP
    Add-VMHostNTPServer -NtpServer $ntpone , $ntptwo -VMHost $vmhost -Confirm:$false
 
    # 设置 ntp 服务为随主机启动
    Get-VMHostService -VMHost $vmhost | where{$_.Key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
 
    # 重启 ntp 服务
    Get-VMHostService -VMHost $vmhost | where{$_.Key -eq "ntpd"} | Restart-VMHostService -Confirm:$false
   
    # 配置管理口上行链路冗余
    Get-VirtualSwitch -Name vSwitch0 | Set-VirtualSwitch -Nic vmnic0,vmnic1 -Confirm:$false

    # 新建存储使用的标准交换机,开启 Jumbo Frame
    New-VirtualSwitch -Name vSwitch1 -Nic vmnic2,vmnic3 -Mtu 9000 -Confirm:$false

    # 新建业务使用的标准交换机,开启 Jumbo Frame
    New-VirtualSwitch -Name vSwitch1 -Nic vmnic4,vmnic5 -Mtu 9000 -Confirm:$false

    # 新建并启用vMotion 网络
    New-VMHostNetworkAdapter -PortGroup vMotion -VirtualSwitch vSwitch0 -IP $vMotion_IP -SubnetMask $vMotion_NetMask -vlanid $vMotion_vLAN -Mtu 9000 
    $vMotion_StartIP += 1
    Get-VMHostNetworkAdapter -Name vmk1  |Set-VMHostNetworkAdapter -VMotionEnabled $true
    
    # 批量创建存储使用的网络端口组
    New-VMHostNetworkAdapter -PortGroup iSCSI01 -VirtualSwitch vSwitch1 -IP $iSCSI01_IP -SubnetMask $iSCSI_NetMask -Mtu 9000
    New-VMHostNetworkAdapter -PortGroup iSCSI02 -VirtualSwitch vSwitch1 -IP $iSCSI02_IP -SubnetMask $iSCSI_NetMask -Mtu 9000
    $iSCSI01_StartIP += 1
    $iSCSI02_StartIP += 1

    # 设置单独的上行链路
    Get-VirtualPortGroup -VirtualSwitch vswitch1 -Name ISCSI01 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive vmnic2 -MakeNicUnused vmnic3
    Get-VirtualPortGroup -VirtualSwitch vswitch1 -Name ISCSI02 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive vmnic3 -MakeNicUnused vmnic2

    # 设置 vLAN
    Get-VirtualPortGroup -Name "iSCSI01" | Set-VirtualPortGroup -Name "iSCSI01" -vlanid $iSCSI01_vLAN
    Get-VirtualPortGroup -Name "iSCSI02" | Set-VirtualPortGroup -Name "iSCSI02" -vlanid $iSCSI02_vLAN

    # 批量启用主机软 iscsi 适配器
    Get-VMHostStorage -VMHost $vmhost | Set-VMHostStorage -SoftwareIScsiEnabled $True
   
    # 根据存储配置最佳实践,设置 iSCSI 高级参数 DelayedAck 为 False
    $HostView = Get-VMHost $vmhost | Get-View
    $HostStorageSystemID = $HostView.configmanager.StorageSystem
    $HostiSCSISoftwareAdapterHBAID = ($HostView.config.storagedevice.   HostBusAdapter | where {$_.Model -match "iSCSI Software"}).device
    $HostStorageSystem = Get-View -ID $HostStorageSystemID
    $HostStorageSystem.UpdateInternetScsiAdvancedOptions   ($HostiSCSISoftwareAdapterHBAID, $null, $options)    
    
    #  端口绑定
    ForEach-Object {
        $vmhostcli = Get-EsxCli -V2 -VMHost $_
        $bind1 = @{
            adapter = 'vmhba65'
            force = $true
            nic = 'vmk2'
        }
        $vmhostcli.iscsi.networkportal.add.Invoke($bind1)
        $bind2 = @{
            adapter = 'vmhba65'
            force = $true
            nic = 'vmk3'
        }
        $vmhostcli.iscsi.networkportal.add.Invoke($bind2)
    
    # 添加 iSCSI 存储
    $HBANumber = Get-VMHostHba -Type iScsi | select device
        foreach ($iSCSI_Target in $iSCSI_Targets){
        New-IScsiHbaTarget -IScsiHba $HBANumber -Address $iSCSI_Target
        }
    
    # 重新扫描 HBA 卡来识别存储
    Get-VMHostStorage  -RescanAllHba
    Get-VMHostStorage  -RescanVmfs
}

### 创建业务使用的网络端口组
foreach($vmhost in $vmhosts)
{
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name VM-Network -VLanId 0
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name App-A -VLanId 1
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name App-B -VLanId 2
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name App-C -VLanId 3
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name Office-OA -VLanId 4
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name Storage-ISCSI -VLanId 16
     Get-VMHost -name $VMhost | Get-VirtualSwitch -name vSwitch2 | New-VirtualPortGroup -name DB-A -VLanId 5
}
```

# 结语
由于主机管理的内容较多,我们本篇文章先到这里,本章我们过了一遍新建集群标准交换机的配置; 下一章会讲分布式交换机的配置,以及常用的主机管理命令还有主机配置文件的管理以及使用.


# 第四章: PowerCLI 管理 Esxi主机配置-第二部分
*** 
# 迁移到分布式交换机设置
## 创建分布式交换机



## 批量创建分布式交换机网络端口组



## 查看Esxi主机
```
Get-VMhost
```

## 获取主机 Iscsi HBA卡的 IQN
```
Get-Cluster -name ClusterA | Get-VMHost | Get-VMHostHba -type iscsi | Select VMhost, IScsiName
```
![](images/c4/get-vmhost-iscsi.png)

## 获取主机光纤存储的 WWPN 号码
```
$VMHosts = Get-VMHost
Foreach ($vmhost in $VMHosts){
$hbas = Get-VMHostHba -type FibreChannel
foreach ($hba in $hbas){
$wwpn = $hba.PortWorldWideName
Write-Host $hba.Device, "|" $hba.Model, "|" "WWPN:"$wwpn
}}
```

## 列出所有主机的时间
```
get-vmhost | select Name,@{Name="Time";Expression={(get-view $_.ExtensionData.configManager.DateTimeSystem).QueryDateTime()}}
```   

## 列出主机上跑的虚拟机数量
```
Get-VMHost | Select @{N="Cluster";E={Get-Cluster -VMHost $_}}, Name, @{N="NumVM";E={($_ | Get-VM).Count}} | Sort Cluster, Name
```
![](images/c4/Get-VMHost.png)

## 列出主机硬件信息
这对于您要管理的主机硬件很有用。该命令将显示硬件供应商，CPU类型，内核数量，CPU插槽数量，CPU速度和内存大小
```
Get-VMHost |Sort Name |Get-View |Select Name, @{N=“Type“;E={$_.Hardware.SystemInfo.Vendor+ “ “ + $_.Hardware.SystemInfo.Model}},@{N=“CPU“;E={“PROC:“ + $_.Hardware.CpuInfo.NumCpuPackages + “ CORES:“ + $_.Hardware.CpuInfo.NumCpuCores + “ MHZ: “ + [math]::round($_.Hardware.CpuInfo.Hz / 1000000, 0)}},@{N=“MEM“;E={“” + [math]::round($_.Hardware.MemorySize / 1GB, 0) + “ GB“}}
```
![](/Images/c4/Get-VMHost-hwinfo.png)

## 查询主机管理网络
这对于查看主机映射了哪些网络很有用。
```
Get-VMHost | Get-VMHostNetwork | Select Hostname, VMKernelGateway -ExpandProperty VirtualNic | Where {$_.ManagementTrafficEnabled} | Select Hostname, PortGroupName, IP, SubnetMask
```
![](images/c4/Get-VMHostNetwork.png)

## 查询主机vMotion网路
这对于查看主机映射了哪些vMotion网络很有用。
```
Get-VMHost | Get-VMHostNetwork | Select Hostname, VMKernelGateway -ExpandProperty VirtualNic | Where {$_.vMotionEnabled} | Select Hostname, PortGroupName, IP, SubnetMask
```
![](images/c4/vMotion-Network.png)

## 列出主机存储多路径策略

```
Get-VMHost | Get-ScsiLun | Select VMHost, ConsoleDeviceName, Vendor, MultipathPolicy
```
![](images/c4/Storage-Policy.png)

## 查询主机DRS状态
列出主机DRS状态的快速命令–如果需要，可以针对多个主机运行。
```
Get-VMHost | Get-Cluster | Select Name, DrsEnabled, DrsMode, DrsAutomationLevel
```
![](images/c4/DRS-query.png)

## 检查主机HA状态,级别
此命令将检查ESX主机或群集上的高可用性状态
```
Get-VMHost | Get-Cluster | Select Name, HAFailoverLevel, HARestartPriority, HAIsolationResponse
```
![](images/c4/HA-query.png)

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