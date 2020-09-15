# 第五章: 快照,函数以及计划任务
***
## 创建/还原/删除虚拟机快照
### 创建快照
```
Get-VM app01a | New-Snapshot -Name "HOL" -Description "HOL Snapshot" -Quiesce -Memory
```   
在创建快照的时候可以显示创建快照的进度条
![创建快照](images/c3/create-snapshot.jpg)
快照创建好之后可以看到一个快照的概览描述
![创建快照](images/c3/create-snapshot-finish.png)

### 查看快照
你也可以用如下命令看来查看快照信息:
```
Get-VM | Get-Snapshot
```
显示结果:
![创建快照](images/c3/get-vm-snapshot.png)
如果你需要看到详细的快照信息,可以在上面的命令基础上加上一些参数:
```
Get-VM|Get-Snapshot|Select-Object -Property Name,VM,SizeGB
```   
显示如下:
![快照详细情况](images/c3/get-vm-snapshot-detail.png)

给虚拟机core-A再创建一个快照;
```
Get-VM core-A | New-Snapshot -Name "HOL-Report" -Description "HOL Snapshot" -Quiesce -Memory
```

### 虚拟机快照报告排序
然后使用如下命令列出所有虚拟机快照并进行排序;
```
Get-VM|Get-Snapshot|Select-Object -Property Name,VM,SizeGB|Sort-Object -Property SizeGB -Descending
```
![快照报告](images/c3/get-vm-snapshot-detail-sort.png)

### 导出虚拟机快照报告为CSV
如果需要将上面运行的报告导出,可以使用Export-CSV命令;
```
Get-VM|Get-Snapshot|Select-Object -Property Name,VM,SizeGB|Sort-Object -Property SizeGB -Descending|Export-CSV -Path SnapshotReport.csv
```

### 还原快照
我们还是拿上面刚做的app01a虚拟机做示例;这台虚拟机上面有名字为"HOL-2112-01"的快照;
```
Get-VM -Name app01a | New-Snapshot -Name "HOL-2112-01"
$snapshot = Get-VM -Name app01a | Get-Snapshot -Name "HOL-2112-01"
Get-VM -Name app01a | Set-VM -Snapshot $snapshot
```
到vCenter上可以看到虚拟机快照回滚成功的消息.
![回滚快照](images/c3/revert-snapshot.png)

## 删除快照
### 对虚拟机app01a创建快照
```
Get-VM app01a | New-Snapshot -Name "HOL2" -Description "HOL Snapshot" -Quiesce -Memory
```
### 对虚拟机app01a创建子快照
```
Get-VM app01a | New-Snapshot -Name "HOL2" -Description "HOL Snapshot Child" -Quiesce -Memory
```

### 查看快照
```
Get-VM | Get-Snapshot | Select VM,Created,Name,SizeGB
```
![查看快照](images/c3/get-vmsnapshot.png)

### 删除快照加-whatif参数
```
Get-VM -Name app01a | Get-Snapshot -Name "HOL2"| Remove-Snapshot -RemoveChildren -whatif
```
加上whatif会告诉你删除快照的后果
![whatif](images/c3/whatif.png)

### 删除快照并确认操作
```
Get-VM -Name app01a | Get-Snapshot -Name "HOL2"| Remove-Snapshot -RemoveChildren
```
![remove-snapshot](images/c3/remove-snapshot.png)

