#!/bin/bash

# Fixed and Complete generateChaincodes_part6.sh
# This script generates full Go chaincode for 8 contracts in part 6.
# Fix: Used <<'EOF' to prevent bash substitution of backticks in Go JSON tags.
# Added complete case for all contracts with customized structs and functions based on fields from errors.
# The Go code is complete with Init, Record/Log functions, Query, and other relevant methods.

set -e  # Stop on first error

contracts=(
    "MonitorNetwork" "MonitorIoT" "LogFault" "LogPerformance" "LogSession" "LogTraffic" "LogInterference" "LogResourceAudit"
)

for contract in "${contracts[@]}"; do
    mkdir -p chaincode/$contract
    case $contract in
        MonitorNetwork)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type MonitorNetwork struct {
    contractapi.Contract
}

type NetworkMonitor struct {
    NetworkID string `json:"networkID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *MonitorNetwork) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *MonitorNetwork) RecordStatus(ctx contractapi.TransactionContextInterface, networkID, status string) error {
    networkMonitor := NetworkMonitor{
        NetworkID: networkID,
        Status: status,
        Timestamp: txTimestamp(ctx),
    }
    networkMonitorJSON, err := json.Marshal(networkMonitor)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, networkMonitorJSON)
}

func (s *MonitorNetwork) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*NetworkMonitor, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("network monitor %s does not exist", networkID)
    }
    var networkMonitor NetworkMonitor
    err = json.Unmarshal(assetJSON, &networkMonitor)
    if err != nil {
        return nil, err
    }
    return &networkMonitor, nil
}

func (s *MonitorNetwork) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*NetworkMonitor, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var networkMonitors []*NetworkMonitor
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var networkMonitor NetworkMonitor
        err = json.Unmarshal(queryResponse.Value, &networkMonitor)
        if err != nil {
            return nil, err
        }
        networkMonitors = append(networkMonitors, &networkMonitor)
    }
    return networkMonitors, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&MonitorNetwork{})
    if err != nil {
        fmt.Printf("Error creating MonitorNetwork chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting MonitorNetwork chaincode: %v", err)
    }
}
EOF
            ;;
        MonitorIoT)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type MonitorIoT struct {
    contractapi.Contract
}

type IoTMonitor struct {
    DeviceID string `json:"deviceID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *MonitorIoT) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *MonitorIoT) RecordStatus(ctx contractapi.TransactionContextInterface, deviceID, status string) error {
    iotMonitor := IoTMonitor{
        DeviceID: deviceID,
        Status: status,
        Timestamp: txTimestamp(ctx),
    }
    iotMonitorJSON, err := json.Marshal(iotMonitor)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotMonitorJSON)
}

func (s *MonitorIoT) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTMonitor, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT monitor %s does not exist", deviceID)
    }
    var iotMonitor IoTMonitor
    err = json.Unmarshal(assetJSON, &iotMonitor)
    if err != nil {
        return nil, err
    }
    return &iotMonitor, nil
}

func (s *MonitorIoT) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTMonitor, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var iotMonitors []*IoTMonitor
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var iotMonitor IoTMonitor
        err = json.Unmarshal(queryResponse.Value, &iotMonitor)
        if err != nil {
            return nil, err
        }
        iotMonitors = append(iotMonitors, &iotMonitor)
    }
    return iotMonitors, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&MonitorIoT{})
    if err != nil {
        fmt.Printf("Error creating MonitorIoT chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting MonitorIoT chaincode: %v", err)
    }
}
EOF
            ;;
        LogFault)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogFault struct {
    contractapi.Contract
}

type FaultLog struct {
    EntityID string `json:"entityID"`
    FaultType string `json:"faultType"`
    Timestamp string `json:"timestamp"`
}

func (s *LogFault) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogFault) LogFault(ctx contractapi.TransactionContextInterface, entityID, faultType string) error {
    faultLog := FaultLog{
        EntityID: entityID,
        FaultType: faultType,
        Timestamp: txTimestamp(ctx),
    }
    faultLogJSON, err := json.Marshal(faultLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, faultLogJSON)
}

func (s *LogFault) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*FaultLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("fault log %s does not exist", entityID)
    }
    var faultLog FaultLog
    err = json.Unmarshal(assetJSON, &faultLog)
    if err != nil {
        return nil, err
    }
    return &faultLog, nil
}

func (s *LogFault) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*FaultLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var faultLogs []*FaultLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var faultLog FaultLog
        err = json.Unmarshal(queryResponse.Value, &faultLog)
        if err != nil {
            return nil, err
        }
        faultLogs = append(faultLogs, &faultLog)
    }
    return faultLogs, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&LogFault{})
    if err != nil {
        fmt.Printf("Error creating LogFault chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogFault chaincode: %v", err)
    }
}
EOF
            ;;
        LogPerformance)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogPerformance struct {
    contractapi.Contract
}

type PerformanceLog struct {
    EntityID string `json:"entityID"`
    Metric string `json:"metric"`
    Value string `json:"value"`
    Timestamp string `json:"timestamp"`
}

func (s *LogPerformance) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogPerformance) LogPerformance(ctx contractapi.TransactionContextInterface, entityID, metric, value string) error {
    performanceLog := PerformanceLog{
        EntityID: entityID,
        Metric: metric,
        Value: value,
        Timestamp: txTimestamp(ctx),
    }
    performanceLogJSON, err := json.Marshal(performanceLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, performanceLogJSON)
}

func (s *LogPerformance) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*PerformanceLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("performance log %s does not exist", entityID)
    }
    var performanceLog PerformanceLog
    err = json.Unmarshal(assetJSON, &performanceLog)
    if err != nil {
        return nil, err
    }
    return &performanceLog, nil
}

func (s *LogPerformance) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*PerformanceLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var performanceLogs []*PerformanceLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var performanceLog PerformanceLog
        err = json.Unmarshal(queryResponse.Value, &performanceLog)
        if err != nil {
            return nil, err
        }
        performanceLogs = append(performanceLogs, &performanceLog)
    }
    return performanceLogs, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&LogPerformance{})
    if err != nil {
        fmt.Printf("Error creating LogPerformance chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogPerformance chaincode: %v", err)
    }
}
EOF
            ;;
        LogSession)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogSession struct {
    contractapi.Contract
}

type SessionLog struct {
    EntityID string `json:"entityID"`
    SessionID string `json:"sessionID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *LogSession) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogSession) LogSession(ctx contractapi.TransactionContextInterface, entityID, sessionID, status string) error {
    sessionLog := SessionLog{
        EntityID: entityID,
        SessionID: sessionID,
        Status: status,
        Timestamp: txTimestamp(ctx),
    }
    sessionLogJSON, err := json.Marshal(sessionLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, sessionLogJSON)
}

func (s *LogSession) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*SessionLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("session log %s does not exist", entityID)
    }
    var sessionLog SessionLog
    err = json.Unmarshal(assetJSON, &sessionLog)
    if err != nil {
        return nil, err
    }
    return &sessionLog, nil
}

func (s *LogSession) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*SessionLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var sessionLogs []*SessionLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var sessionLog SessionLog
        err = json.Unmarshal(queryResponse.Value, &sessionLog)
        if err != nil {
            return nil, err
        }
        sessionLogs = append(sessionLogs, &sessionLog)
    }
    return sessionLogs, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&LogSession{})
    if err != nil {
        fmt.Printf("Error creating LogSession chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogSession chaincode: %v", err)
    }
}
EOF
            ;;
        LogTraffic)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogTraffic struct {
    contractapi.Contract
}

type TrafficLog struct {
    EntityID string `json:"entityID"`
    Traffic string `json:"traffic"`
    Timestamp string `json:"timestamp"`
}

func (s *LogTraffic) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogTraffic) LogTraffic(ctx contractapi.TransactionContextInterface, entityID, traffic string) error {
    trafficLog := TrafficLog{
        EntityID: entityID,
        Traffic: traffic,
        Timestamp: txTimestamp(ctx),
    }
    trafficLogJSON, err := json.Marshal(trafficLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, trafficLogJSON)
}

func (s *LogTraffic) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*TrafficLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("traffic log %s does not exist", entityID)
    }
    var trafficLog TrafficLog
    err = json.Unmarshal(assetJSON, &trafficLog)
    if err != nil {
        return nil, err
    }
    return &trafficLog, nil
}

func (s *LogTraffic) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*TrafficLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var trafficLogs []*TrafficLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var trafficLog TrafficLog
        err = json.Unmarshal(queryResponse.Value, &trafficLog)
        if err != nil {
            return nil, err
        }
        trafficLogs = append(trafficLogs, &trafficLog)
    }
    return trafficLogs, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&LogTraffic{})
    if err != nil {
        fmt.Printf("Error creating LogTraffic chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogTraffic chaincode: %v", err)
    }
}
EOF
            ;;
        LogInterference)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogInterference struct {
    contractapi.Contract
}

type InterferenceLog struct {
    EntityID string `json:"entityID"`
    InterferenceLevel string `json:"interferenceLevel"`
    Timestamp string `json:"timestamp"`
}

func (s *LogInterference) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogInterference) LogInterference(ctx contractapi.TransactionContextInterface, entityID, interferenceLevel string) error {
    interferenceLog := InterferenceLog{
        EntityID: entityID,
        InterferenceLevel: interferenceLevel,
        Timestamp: txTimestamp(ctx),
    }
    interferenceLogJSON, err := json.Marshal(interferenceLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, interferenceLogJSON)
}

func (s *LogInterference) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*InterferenceLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("interference log %s does not exist", entityID)
    }
    var interferenceLog InterferenceLog
    err = json.Unmarshal(assetJSON, &interferenceLog)
    if err != nil {
        return nil, err
    }
    return &interferenceLog, nil
}

func (s *LogInterference) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*InterferenceLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var interferenceLogs []*InterferenceLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var interferenceLog InterferenceLog
        err = json.Unmarshal(queryResponse.Value, &interferenceLog)
        if err != nil {
            return nil, err
        }
        interferenceLogs = append(interferenceLogs, &interferenceLog)
    }
    return interferenceLogs, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&LogInterference{})
    if err != nil {
        fmt.Printf("Error creating LogInterference chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogInterference chaincode: %v", err)
    }
}
EOF
            ;;
        LogResourceAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogResourceAudit struct {
    contractapi.Contract
}

type ResourceAuditLog struct {
    EntityID string `json:"entityID"`
    Resource string `json:"resource"`
    Amount string `json:"amount"`
    Timestamp string `json:"timestamp"`
}

func (s *LogResourceAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogResourceAudit) LogResourceAudit(ctx contractapi.TransactionContextInterface, entityID, resource, amount string) error {
    resourceAuditLog := ResourceAuditLog{
        EntityID: entityID,
        Resource: resource,
        Amount: amount,
        Timestamp: txTimestamp(ctx),
    }
    resourceAuditLogJSON, err := json.Marshal(resourceAuditLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, resourceAuditLogJSON)
}

func (s *LogResourceAudit) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*ResourceAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("resource audit log %s does not exist", entityID)
    }
    var resourceAuditLog ResourceAuditLog
    err = json.Unmarshal(assetJSON, &resourceAuditLog)
    if err != nil {
        return nil, err
    }
    return &resourceAuditLog, nil
}

func (s *LogResourceAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*ResourceAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var resourceAuditLogs []*ResourceAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var resourceAuditLog ResourceAuditLog
        err = json.Unmarshal(queryResponse.Value, &resourceAuditLog)
        if err != nil {
            return nil, err
        }
        resourceAuditLogs = append(resourceAuditLogs, &resourceAuditLog)
    }
    return resourceAuditLogs, nil
}

// txTimestamp returns the deterministic transaction timestamp from the
// transaction proposal. Unlike time.Now(), this value is identical across
// all endorsing peers, keeping the chaincode deterministic.
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

func main() {
    chaincode, err := contractapi.NewChaincode(&LogResourceAudit{})
    if err != nil {
        fmt.Printf("Error creating LogResourceAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogResourceAudit chaincode: %v", err)
    }
}
EOF
            ;;
    esac

    # ساخت go.mod + vendor برای این قرارداد (مثل part1)
    (
      cd "chaincode/$contract"
      cat > go.mod <<GOMOD
module $contract

go 1.21

require github.com/hyperledger/fabric-contract-api-go v1.2.2
GOMOD
      go mod tidy >/dev/null 2>&1
      go mod vendor >/dev/null 2>&1
    )
done

echo "Generated chaincode for ${#contracts[@]} contracts in part 6:"
for contract in "${contracts[@]}"; do
    if [ -f "chaincode/$contract/chaincode.go" ]; then
        echo " - $contract: OK"
    else
        echo " - $contract: Failed"
    fi
done
