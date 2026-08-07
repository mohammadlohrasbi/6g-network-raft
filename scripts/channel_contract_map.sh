#!/bin/bash
# نگاشت قرارداد ↔ کانال برای شبکه 6G — ۸۶ قرارداد در ۲۰ کانال
# این فایل توسط network.sh منبع (source) می‌شود.
#
# نحوه استفاده در network.sh:
#   source channel_contract_map.sh
#   for ch in "${CHANNELS[@]}"; do
#     for cc in ${CHANNEL_CONTRACTS[$ch]}; do
#       # نصب/approve/commit قرارداد cc روی کانال ch
#     done
#   done

# لیست ۲۰ کانال
CHANNELS=(
  networkchannel resourcechannel performancechannel iotchannel authchannel
  connectivitychannel sessionchannel policychannel auditchannel securitychannel
  datachannel analyticschannel monitoringchannel managementchannel
  optimizationchannel faultchannel trafficchannel accesschannel
  compliancechannel integrationchannel
)

# نگاشت هر کانال به قراردادهایش (associative array)
declare -A CHANNEL_CONTRACTS=(
  [networkchannel]="LocationBasedNetworkLoad LocationBasedNetworkHealth ManageNetwork MonitorNetwork"
  [resourcechannel]="LocationBasedResourceAllocation LocationBasedIoTResource AllocateResource LogResourceAudit MonitorResourceUsage"
  [performancechannel]="LocationBasedLatency LogPerformance LogNetworkPerformance LogPerformanceAudit"
  [iotchannel]="LocationBasedIoTConnection LocationBasedIoTBandwidth LocationBasedIoTStatus LocationBasedIoTFault LocationBasedIoTSession ManageIoTDevice MonitorIoT LogIoTActivity"
  [authchannel]="LocationBasedIoTAuthentication AuthenticateUser AuthenticateIoT VerifyIdentity"
  [connectivitychannel]="LocationBasedConnection LocationBasedRoaming ConnectUser ConnectIoT LogConnectionAudit"
  [sessionchannel]="LocationBasedSessionManagement LocationBasedIoTSession ManageSession LogSession LogSessionAudit"
  [policychannel]="SetPolicy GetPolicy UpdatePolicy LogPolicyAudit LogPolicyChange"
  [auditchannel]="LogNetworkAudit LogAntennaAudit LogIoTAudit LogUserAudit LogAccessAudit LogSecurityAudit LogComplianceAudit"
  [securitychannel]="EncryptData DecryptData SecureCommunication LogSecurityEvent"
  [datachannel]="LocationBasedAssignment LocationBasedBandwidth LocationBasedSignalStrength LocationBasedSignalQuality"
  [analyticschannel]="LocationBasedQoS LocationBasedCoverage LocationBasedEnergy"
  [monitoringchannel]="MonitorTraffic MonitorInterference LocationBasedStatus"
  [managementchannel]="ManageAntenna ManageUser LocationBasedAntennaConfig LocationBasedPowerManagement LocationBasedChannelAllocation"
  [optimizationchannel]="OptimizeNetwork BalanceLoad LocationBasedDynamicRouting"
  [faultchannel]="LocationBasedFault LocationBasedIoTFault LogFault"
  [trafficchannel]="LocationBasedTraffic LogTraffic LocationBasedCongestion"
  [accesschannel]="RegisterUser RegisterIoT RevokeUser RevokeIoT AssignRole LocationBasedIoTRegistration LocationBasedIoTRevocation LogAccessControl"
  [compliancechannel]="LogComplianceAudit LocationBasedPriority"
  [integrationchannel]="LocationBasedInterference LocationBasedSignalStrength LocationBasedUserActivity LogUserActivity LogInterference"
)
