#!/bin/bash

# Fixed and Complete generateChaincodes_part10.sh
# This script generates full Go chaincode for 9 contracts in part 10.
# Fix: Used <<'EOF' to prevent bash substitution of backticks in Go JSON tags.
# Added complete case for all contracts with customized structs and functions.
# The Go code is complete with Init, Log functions, Query, and main.

contracts=(
    "LogNetworkAudit" "LogAntennaAudit" "LogIoTAudit" "LogUserAudit" "LogPolicyChange" "LogAccessAudit" "LogPerformanceAudit" "LogSecurityAudit" "LogComplianceAudit"
)

for contract in "${contracts[@]}"; do
    mkdir -p chaincode/$contract
    case $contract in
        LogNetworkAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogNetworkAudit struct {
    contractapi.Contract
}

type NetworkAuditLog struct {
    NetworkID string `json:"networkID"`
    Action    string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogNetworkAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogNetworkAudit) Log(ctx contractapi.TransactionContextInterface, networkID, action string) error {
    log := NetworkAuditLog{
        NetworkID: networkID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, logJSON)
}

func (s *LogNetworkAudit) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*NetworkAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("network audit log %s does not exist", networkID)
    }
    var log NetworkAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogNetworkAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*NetworkAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*NetworkAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log NetworkAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogNetworkAudit{})
    if err != nil {
        fmt.Printf("Error creating LogNetworkAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogNetworkAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogAntennaAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogAntennaAudit struct {
    contractapi.Contract
}

type AntennaAuditLog struct {
    AntennaID string `json:"antennaID"`
    Action    string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogAntennaAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogAntennaAudit) Log(ctx contractapi.TransactionContextInterface, antennaID, action string) error {
    log := AntennaAuditLog{
        AntennaID: antennaID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(antennaID, logJSON)
}

func (s *LogAntennaAudit) QueryAsset(ctx contractapi.TransactionContextInterface, antennaID string) (*AntennaAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(antennaID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("antenna audit log %s does not exist", antennaID)
    }
    var log AntennaAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogAntennaAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*AntennaAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*AntennaAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log AntennaAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogAntennaAudit{})
    if err != nil {
        fmt.Printf("Error creating LogAntennaAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogAntennaAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogIoTAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogIoTAudit struct {
    contractapi.Contract
}

type IoTAuditLog struct {
    DeviceID string `json:"deviceID"`
    Action   string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogIoTAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogIoTAudit) Log(ctx contractapi.TransactionContextInterface, deviceID, action string) error {
    log := IoTAuditLog{
        DeviceID:  deviceID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, logJSON)
}

func (s *LogIoTAudit) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT audit log %s does not exist", deviceID)
    }
    var log IoTAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogIoTAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*IoTAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log IoTAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogIoTAudit{})
    if err != nil {
        fmt.Printf("Error creating LogIoTAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogIoTAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogUserAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogUserAudit struct {
    contractapi.Contract
}

type UserAuditLog struct {
    UserID string `json:"userID"`
    Action string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogUserAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogUserAudit) Log(ctx contractapi.TransactionContextInterface, userID, action string) error {
    log := UserAuditLog{
        UserID:    userID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, logJSON)
}

func (s *LogUserAudit) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*UserAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user audit log %s does not exist", userID)
    }
    var log UserAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogUserAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*UserAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*UserAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log UserAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogUserAudit{})
    if err != nil {
        fmt.Printf("Error creating LogUserAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogUserAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogPolicyChange)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogPolicyChange struct {
    contractapi.Contract
}

type PolicyChangeLog struct {
    PolicyID string `json:"policyID"`
    Change   string `json:"change"`
    Timestamp string `json:"timestamp"`
}

func (s *LogPolicyChange) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogPolicyChange) Log(ctx contractapi.TransactionContextInterface, policyID, change string) error {
    log := PolicyChangeLog{
        PolicyID:  policyID,
        Change:    change,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(policyID, logJSON)
}

func (s *LogPolicyChange) QueryAsset(ctx contractapi.TransactionContextInterface, policyID string) (*PolicyChangeLog, error) {
    assetJSON, err := ctx.GetStub().GetState(policyID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("policy change log %s does not exist", policyID)
    }
    var log PolicyChangeLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogPolicyChange) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*PolicyChangeLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*PolicyChangeLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log PolicyChangeLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogPolicyChange{})
    if err != nil {
        fmt.Printf("Error creating LogPolicyChange chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogPolicyChange chaincode: %v", err)
    }
}
EOF
            ;;
        LogAccessAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogAccessAudit struct {
    contractapi.Contract
}

type AccessAuditLog struct {
    EntityID string `json:"entityID"`
    Action   string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogAccessAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogAccessAudit) Log(ctx contractapi.TransactionContextInterface, entityID, action string) error {
    log := AccessAuditLog{
        EntityID:  entityID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, logJSON)
}

func (s *LogAccessAudit) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*AccessAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("access audit log %s does not exist", entityID)
    }
    var log AccessAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogAccessAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*AccessAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*AccessAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log AccessAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogAccessAudit{})
    if err != nil {
        fmt.Printf("Error creating LogAccessAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogAccessAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogPerformanceAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogPerformanceAudit struct {
    contractapi.Contract
}

type PerformanceAuditLog struct {
    EntityID string `json:"entityID"`
    Metric   string `json:"metric"`
    Value    string `json:"value"`
    Timestamp string `json:"timestamp"`
}

func (s *LogPerformanceAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogPerformanceAudit) Log(ctx contractapi.TransactionContextInterface, entityID, metric, value string) error {
    log := PerformanceAuditLog{
        EntityID:  entityID,
        Metric:    metric,
        Value:     value,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, logJSON)
}

func (s *LogPerformanceAudit) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*PerformanceAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("performance audit log %s does not exist", entityID)
    }
    var log PerformanceAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogPerformanceAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*PerformanceAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*PerformanceAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log PerformanceAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogPerformanceAudit{})
    if err != nil {
        fmt.Printf("Error creating LogPerformanceAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogPerformanceAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogSecurityAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogSecurityAudit struct {
    contractapi.Contract
}

type SecurityAuditLog struct {
    EntityID string `json:"entityID"`
    Event    string `json:"event"`
    Timestamp string `json:"timestamp"`
}

func (s *LogSecurityAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogSecurityAudit) Log(ctx contractapi.TransactionContextInterface, entityID, event string) error {
    log := SecurityAuditLog{
        EntityID:  entityID,
        Event:     event,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, logJSON)
}

func (s *LogSecurityAudit) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*SecurityAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("security audit log %s does not exist", entityID)
    }
    var log SecurityAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogSecurityAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*SecurityAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*SecurityAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log SecurityAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogSecurityAudit{})
    if err != nil {
        fmt.Printf("Error creating LogSecurityAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogSecurityAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogComplianceAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogComplianceAudit struct {
    contractapi.Contract
}

type ComplianceAuditLog struct {
    EntityID string `json:"entityID"`
    ComplianceStatus string `json:"complianceStatus"`
    Timestamp string `json:"timestamp"`
}

func (s *LogComplianceAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogComplianceAudit) Log(ctx contractapi.TransactionContextInterface, entityID, complianceStatus string) error {
    log := ComplianceAuditLog{
        EntityID: entityID,
        ComplianceStatus: complianceStatus,
        Timestamp: txTimestamp(ctx),
    }
    logJSON, err := json.Marshal(log)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, logJSON)
}

func (s *LogComplianceAudit) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*ComplianceAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("compliance audit log %s does not exist", entityID)
    }
    var log ComplianceAuditLog
    err = json.Unmarshal(assetJSON, &log)
    if err != nil {
        return nil, err
    }
    return &log, nil
}

func (s *LogComplianceAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*ComplianceAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var logs []*ComplianceAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var log ComplianceAuditLog
        err = json.Unmarshal(queryResponse.Value, &log)
        if err != nil {
            return nil, err
        }
        logs = append(logs, &log)
    }
    return logs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogComplianceAudit{})
    if err != nil {
        fmt.Printf("Error creating LogComplianceAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogComplianceAudit chaincode: %v", err)
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

echo "Generated chaincode for ${#contracts[@]} contracts in part 10:"
for contract in "${contracts[@]}"; do
    if [ -f "chaincode/$contract/chaincode.go" ]; then
        echo " - $contract: OK"
    else
        echo " - $contract: Failed"
    fi
done
