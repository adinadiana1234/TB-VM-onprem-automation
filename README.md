# Resource Manager Thingsboard automation stack

## ORM Stack to deploy a VM.Standard.E4.Flex shape on an Oracle Linux E4.Flex shape

- this is an ORM stack to deploy Thingsboard CE on a compute with a VM.Standard.E4.Flex shape on an Oracle Linux E4.Flex shape
- it requires a VCN and a subnet where the VM will be deployed. In the subnet, ports TCP 22,80,443,1883 and UDP 5683 need to be open. 

    
  The cloudinit will perform all the steps necessary to deploy Thingsboard, using a PostgreSQL database and Kafka as queuing service, as described in the Thingsboard documentation here: https://thingsboard.io/docs/user-guide/install/rhel/

  The script also generates a log on the compute: /var/log/install_thingsboard.log

# Initial login credentials:

The Thingsboard interface can be accessed on: http://<public_VM_IP>:8080.
  - System Administrator: sysadmin@thingsboard.org / sysadmin
  - Tenant Administrator: tenant@thingsboard.org / tenant
  - Customer User: customer@thingsboard.org / customer
