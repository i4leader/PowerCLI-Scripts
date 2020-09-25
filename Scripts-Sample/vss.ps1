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