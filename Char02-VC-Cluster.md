# 第二章: 配置vCenter 以及 vSphere集群
***

## 1. 连接vCenter
使用PowerCLI来管理vSphere环境,那第一步需要做的是将PowerCLI连接到vCenter;如下是通常情况下的使用方法;
```
Connect-VIServer -Server vCenter.example.com -User 'Administrator@vsphere.local' -Password 'MyPassword'
```   

如果用户环境使用了系统Proxy,我们也可以在PowerCLI中配置系统的Proxy;
```
Set-PowerCLIConfiguration -ProxyPolicy UseSystemProxy
```  
或者如果不用Proxy,则可以改回来
```   
Set-PowerCLIConfiguration -ProxyPolicy NoProxy
```   


## 2. 创建数据中心
创建名称为MyFirstDatacenter的数据中心.
```   
New-Datacenter -location (Get-Folder -NoRecursion) -Name MyFirstDatacenter
```  

## 3. 创建集群
在NJ-Datacenter中创建名字为Cluster001的集群.
```
New-Cluster –Name Cluster001 –Location “NJ-Datacenter”
```

在Primary数据中心中创建名称为ClusterA的集群,顺带把集群HA和DRS也开了
```
New-Cluster -Location (Get-Datacenter -Name "Primary") -Name ClusterA -HAEnabled -DRSEnabled -DRSAutomationLevel FullyAutomated
```   

##3. 添加主机到集群中
查看vCenter Server中链接的所有主机;
```
Get-VMHost
```
添加主机的命令
```
Add-VMHost -Name Host -Location (Get-Datacenter DC) -User root -Password pass
```


##4. 配置集群
为了设置群集的高级功能（包括HA，DRS和EVC），即配置群集的高可用和动态资源平衡功能，请执行以下步骤：
1. 对任何现有群集的更改将使用Set-Cluster cmdlet。 Set-Cluster cmdlet和New-Cluster cmdlet有相同的功能。使用**Set-Cluster**，您将使用-Cluster 参数指定集群，然后可以对所需的集群进行任何配置更改。让我们快速开始,先禁用HA：
```
Set-Cluster -Cluster “ClusterA” -HAEnable $false
```
将\$false更改为$true，则为启用HA功能。
```
Set-Cluster -Cluster“ ClusterB” -HAEnable $true
```

2. 接下来，您可能想要更改群集上HA的AdmissionControl和故障转移级别设置。同样，您转到Set-Cluster cmdlet进行这些设置更改。 -HAAdmissionControlEnabled参数控制是否打开“准入控制”。 -HAFailoverLevel参数设置为1到4之间的数字，指定您希望集群能够承受多少主机故障。您将以身作则，以度过一次主机故障的麻烦：
```
Set-Cluster -Cluster“ ClusterA” -HAadmissionControlEnabled $true-HAFailoverLevel 1
```

3. 接下来，您可以再次使用Set-Cluster cmdlet来为群集设置IsolationResponse和RestartPriority设置。首先，如果主机变为隔离状态，则使用-HAIsolationResponse设置行为。接下来，使用-HARestartPriority设置默认优先级以重启集群中的VM：
```
Set-Cluster “ClusterA” -HAIsolationResponse shutdown -HaRestartPriority
```
中
还需要注意的是，所有这些设置都可以组合在一个Set-Cluster cmdlet中。

4. 它也通常在群集上更改DRS模式。Todothis，您可以再次使用Set-Cluster cmdlet，但是您将使用-DrsAutomationLevel参数设置模式：
```
Set-Cluster -Cluster“ ClusterA” -DrsAutomationLevel手册-确认：$false
```

更常见的是，您可能希望将DRS模式设置为全自动：
```
Set-Cluster -Cluster“ ClusterA” -DrsAutomationLevel FullyAutomatic -Confirm：$false
``` 

5. 接下来，在此示例中，您将通过定义DRS规则来确保我们的域控制器不在同一ESXi节点上运行。首先，您需要检索一个
Get-VM cmdlet的域控制器VM的列表。 New-DrsRule cmdlet允许您创建KeepTogether或Separate规则。语法非常简单。您需要为我们的规则指定一个名称，一个集群，无论这是否是KeepTogether规则，最后要指定一个变量传递哪些VM：
```
$domaincontrollers = Get-VM-Name “DC*”
New-DrsRule -Name “Single DC” -Cluster “ClusterA” -enable $true -KeepTogether $false -VM $domaincontrollers
```

6. 从PowerCLI直接报告EVC模​​式设置。首先，必须检索群集对象和EVC模式设置作为该对象的参数：
```
Get-Cluster “ClusterA” |Select Name，EVCMode
```

7. 使用Set-Cluster cmdlet更改EVC模式设置非常简单.
```
Set-Cluster -Cluster “ClusterB” -EVCMode 'intel-ivybridge'
```
