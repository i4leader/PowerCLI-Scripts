

The so-called yellow and blue folders are from pre-vSphere 6 days.

 

Now we have 4 types of folders that you can create (and they are all yellow-orange)

    Host and Cluster
    VM and Template
    Network
    Storage

 

To make it a bit more complicated, as long as you stay (in the tree structure) above a Datacenter, the folders will not be of a specific of these 4 types.

 

Folders can be created at a few specific locations, like under the vCenter, Datacenter and other folders

For example

 

New-Folder -Name Folder1 -Location (Get-Datacenter -Name DC1)

 

When you want to create a folder under a Datacenter, you have to pick one of the 4 types above.

Currently not yet supported via a cmdlet, but you can pick the (hidden) parent-folder, and thus determine the type of the new folder.

For example (this is using the vSphere API method)

 

$dc = Get-Datacenter -Name DC1

 

$hostFolder = Get-View -id $dc.ExtensionData.HostFolder

$hostFolder.CreateFolder('TestHostFolder')

 

$vmFolder = Get-View -id $dc.ExtensionData.VmFolder

$vmFolder.CreateFolder('TestVmFolder')

 

$netFolder = Get-View -id $dc.ExtensionData.NetworkFolder

$netFolder.CreateFolder('TestNetFolder')

 

$dsFolder = Get-View -id $dc.ExtensionData.DatastoreFolder

$dsFolder.CreateFolder('TestDSFolder')
