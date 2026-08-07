#!/bin/bash

# Fixed and Complete generateChaincodes_part7.sh
# This script generates full Go chaincode for 9 contracts in part 7.
# Fix: Used <<'EOF' to prevent bash substitution of backticks in Go JSON tags.
# Added complete case for all contracts with customized structs and functions.
# The Go code is complete with Init, Record/Log/Balance/Optimize functions, Query, and other relevant methods.

contracts=(
    "BalanceLoad" "AllocateResource" "OptimizeNetwork" "ManageSession" "LogNetworkPerformance"
    "LogUserActivity" "LogIoTActivity" "LogSessionAudit" "LogConnectionAudit"
)

for contract in "${contracts[@]}"; do
    mkdir -p chaincode/$contract
    case $contract in
        BalanceLoad)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type BalanceLoad struct {
    contractapi.Contract
}

type LoadBalance struct {
    NetworkID string `json:"networkID"`
    Load      string `json:"load"`
    Timestamp string `json:"timestamp"`
}

func (s *BalanceLoad) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *BalanceLoad) Balance(ctx contractapi.TransactionContextInterface, networkID, load string) error {
    loadBalance := LoadBalance{
        NetworkID: networkID,
        Load:      load,
        Timestamp: txTimestamp(ctx),
    }
    loadBalanceJSON, err := json.Marshal(loadBalance)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, loadBalanceJSON)
}

func (s *BalanceLoad) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*LoadBalance, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("load balance %s does not exist", networkID)
    }
    var loadBalance LoadBalance
    err = json.Unmarshal(assetJSON, &loadBalance)
    if err != nil {
        return nil, err
    }
    return &loadBalance, nil
}

func (s *BalanceLoad) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*LoadBalance, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var loadBalances []*LoadBalance
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var loadBalance LoadBalance
        err = json.Unmarshal(queryResponse.Value, &loadBalance)
        if err != nil {
            return nil, err
        }
        loadBalances = append(loadBalances, &loadBalance)
    }
    return loadBalances, nil
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
    chaincode, err := contractapi.NewChaincode(&BalanceLoad{})
    if err != nil {
        fmt.Printf("Error creating BalanceLoad chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting BalanceLoad chaincode: %v", err)
    }
}
EOF
            ;;
        AllocateResource)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type AllocateResource struct {
    contractapi.Contract
}

type ResourceAllocation struct {
    EntityID string `json:"entityID"`
    Resource string `json:"resource"`
    Amount   string `json:"amount"`
    Timestamp string `json:"timestamp"`
}

func (s *AllocateResource) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *AllocateResource) Allocate(ctx contractapi.TransactionContextInterface, entityID, resource, amount string) error {
    resourceAllocation := ResourceAllocation{
        EntityID: entityID,
        Resource: resource,
        Amount:   amount,
        Timestamp: txTimestamp(ctx),
    }
    resourceAllocationJSON, err := json.Marshal(resourceAllocation)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, resourceAllocationJSON)
}

func (s *AllocateResource) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*ResourceAllocation, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("resource allocation %s does not exist", entityID)
    }
    var resourceAllocation ResourceAllocation
    err = json.Unmarshal(assetJSON, &resourceAllocation)
    if err != nil {
        return nil, err
    }
    return &resourceAllocation, nil
}

func (s *AllocateResource) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*ResourceAllocation, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var resourceAllocations []*ResourceAllocation
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var resourceAllocation ResourceAllocation
        err = json.Unmarshal(queryResponse.Value, &resourceAllocation)
        if err != nil {
            return nil, err
        }
        resourceAllocations = append(resourceAllocations, &resourceAllocation)
    }
    return resourceAllocations, nil
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
    chaincode, err := contractapi.NewChaincode(&AllocateResource{})
    if err != nil {
        fmt.Printf("Error creating AllocateResource chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting AllocateResource chaincode: %v", err)
    }
}
EOF
            ;;
        OptimizeNetwork)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type OptimizeNetwork struct {
    contractapi.Contract
}

type NetworkOptimization struct {
    NetworkID string `json:"networkID"`
    Strategy  string `json:"strategy"`
    Timestamp string `json:"timestamp"`
}

func (s *OptimizeNetwork) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *OptimizeNetwork) Optimize(ctx contractapi.TransactionContextInterface, networkID, strategy string) error {
    networkOptimization := NetworkOptimization{
        NetworkID: networkID,
        Strategy:  strategy,
        Timestamp: txTimestamp(ctx),
    }
    networkOptimizationJSON, err := json.Marshal(networkOptimization)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, networkOptimizationJSON)
}

func (s *OptimizeNetwork) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*NetworkOptimization, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("network optimization %s does not exist", networkID)
    }
    var networkOptimization NetworkOptimization
    err = json.Unmarshal(assetJSON, &networkOptimization)
    if err != nil {
        return nil, err
    }
    return &networkOptimization, nil
}

func (s *OptimizeNetwork) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*NetworkOptimization, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var networkOptimizations []*NetworkOptimization
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var networkOptimization NetworkOptimization
        err = json.Unmarshal(queryResponse.Value, &networkOptimization)
        if err != nil {
            return nil, err
        }
        networkOptimizations = append(networkOptimizations, &networkOptimization)
    }
    return networkOptimizations, nil
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
    chaincode, err := contractapi.NewChaincode(&OptimizeNetwork{})
    if err != nil {
        fmt.Printf("Error creating OptimizeNetwork chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting OptimizeNetwork chaincode: %v", err)
    }
}
EOF
            ;;
        ManageSession)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ManageSession struct {
    contractapi.Contract
}

type Session struct {
    EntityID  string `json:"entityID"`
    SessionID string `json:"sessionID"`
    Status    string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *ManageSession) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *ManageSession) StartSession(ctx contractapi.TransactionContextInterface, entityID, sessionID string) error {
    session := Session{
        EntityID:  entityID,
        SessionID: sessionID,
        Status:    "Active",
        Timestamp: txTimestamp(ctx),
    }
    sessionJSON, err := json.Marshal(session)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, sessionJSON)
}

func (s *ManageSession) EndSession(ctx contractapi.TransactionContextInterface, entityID string) error {
    session, err := s.QueryAsset(ctx, entityID)
    if err != nil {
        return err
    }
    session.Status = "Ended"
    session.Timestamp = txTimestamp(ctx)
    sessionJSON, err := json.Marshal(session)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, sessionJSON)
}

func (s *ManageSession) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*Session, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("session %s does not exist", entityID)
    }
    var session Session
    err = json.Unmarshal(assetJSON, &session)
    if err != nil {
        return nil, err
    }
    return &session, nil
}

func (s *ManageSession) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Session, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var sessions []*Session
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var session Session
        err = json.Unmarshal(queryResponse.Value, &session)
        if err != nil {
            return nil, err
        }
        sessions = append(sessions, &session)
    }
    return sessions, nil
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
    chaincode, err := contractapi.NewChaincode(&ManageSession{})
    if err != nil {
        fmt.Printf("Error creating ManageSession chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting ManageSession chaincode: %v", err)
    }
}
EOF
            ;;
        LogNetworkPerformance)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogNetworkPerformance struct {
    contractapi.Contract
}

type NetworkPerformanceLog struct {
    NetworkID string `json:"networkID"`
    Metric    string `json:"metric"`
    Value     string `json:"value"`
    Timestamp string `json:"timestamp"`
}

func (s *LogNetworkPerformance) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogNetworkPerformance) Log(ctx contractapi.TransactionContextInterface, networkID, metric, value string) error {
    performanceLog := NetworkPerformanceLog{
        NetworkID: networkID,
        Metric:    metric,
        Value:     value,
        Timestamp: txTimestamp(ctx),
    }
    performanceLogJSON, err := json.Marshal(performanceLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, performanceLogJSON)
}

func (s *LogNetworkPerformance) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*NetworkPerformanceLog, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("network performance log %s does not exist", networkID)
    }
    var performanceLog NetworkPerformanceLog
    err = json.Unmarshal(assetJSON, &performanceLog)
    if err != nil {
        return nil, err
    }
    return &performanceLog, nil
}

func (s *LogNetworkPerformance) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*NetworkPerformanceLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var performanceLogs []*NetworkPerformanceLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var performanceLog NetworkPerformanceLog
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
    chaincode, err := contractapi.NewChaincode(&LogNetworkPerformance{})
    if err != nil {
        fmt.Printf("Error creating LogNetworkPerformance chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogNetworkPerformance chaincode: %v", err)
    }
}
EOF
            ;;
        LogUserActivity)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogUserActivity struct {
    contractapi.Contract
}

type UserActivityLog struct {
    UserID    string `json:"userID"`
    Activity  string `json:"activity"`
    Timestamp string `json:"timestamp"`
}

func (s *LogUserActivity) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogUserActivity) Log(ctx contractapi.TransactionContextInterface, userID, activity string) error {
    userActivityLog := UserActivityLog{
        UserID:    userID,
        Activity:  activity,
        Timestamp: txTimestamp(ctx),
    }
    userActivityLogJSON, err := json.Marshal(userActivityLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userActivityLogJSON)
}

func (s *LogUserActivity) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*UserActivityLog, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user activity log %s does not exist", userID)
    }
    var userActivityLog UserActivityLog
    err = json.Unmarshal(assetJSON, &userActivityLog)
    if err != nil {
        return nil, err
    }
    return &userActivityLog, nil
}

func (s *LogUserActivity) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*UserActivityLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var userActivityLogs []*UserActivityLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var userActivityLog UserActivityLog
        err = json.Unmarshal(queryResponse.Value, &userActivityLog)
        if err != nil {
            return nil, err
        }
        userActivityLogs = append(userActivityLogs, &userActivityLog)
    }
    return userActivityLogs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogUserActivity{})
    if err != nil {
        fmt.Printf("Error creating LogUserActivity chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogUserActivity chaincode: %v", err)
    }
}
EOF
            ;;
        LogIoTActivity)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogIoTActivity struct {
    contractapi.Contract
}

type IoTActivityLog struct {
    DeviceID  string `json:"deviceID"`
    Activity  string `json:"activity"`
    Timestamp string `json:"timestamp"`
}

func (s *LogIoTActivity) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogIoTActivity) Log(ctx contractapi.TransactionContextInterface, deviceID, activity string) error {
    iotActivityLog := IoTActivityLog{
        DeviceID:  deviceID,
        Activity:  activity,
        Timestamp: txTimestamp(ctx),
    }
    iotActivityLogJSON, err := json.Marshal(iotActivityLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotActivityLogJSON)
}

func (s *LogIoTActivity) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTActivityLog, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT activity log %s does not exist", deviceID)
    }
    var iotActivityLog IoTActivityLog
    err = json.Unmarshal(assetJSON, &iotActivityLog)
    if err != nil {
        return nil, err
    }
    return &iotActivityLog, nil
}

func (s *LogIoTActivity) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTActivityLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var iotActivityLogs []*IoTActivityLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var iotActivityLog IoTActivityLog
        err = json.Unmarshal(queryResponse.Value, &iotActivityLog)
        if err != nil {
            return nil, err
        }
        iotActivityLogs = append(iotActivityLogs, &iotActivityLog)
    }
    return iotActivityLogs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogIoTActivity{})
    if err != nil {
        fmt.Printf("Error creating LogIoTActivity chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogIoTActivity chaincode: %v", err)
    }
}
EOF
            ;;
        LogSessionAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogSessionAudit struct {
    contractapi.Contract
}

type SessionAuditLog struct {
    EntityID  string `json:"entityID"`
    SessionID string `json:"sessionID"`
    Action    string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogSessionAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogSessionAudit) Log(ctx contractapi.TransactionContextInterface, entityID, sessionID, action string) error {
    sessionAuditLog := SessionAuditLog{
        EntityID:  entityID,
        SessionID: sessionID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    sessionAuditLogJSON, err := json.Marshal(sessionAuditLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, sessionAuditLogJSON)
}

func (s *LogSessionAudit) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*SessionAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("session audit log %s does not exist", entityID)
    }
    var sessionAuditLog SessionAuditLog
    err = json.Unmarshal(assetJSON, &sessionAuditLog)
    if err != nil {
        return nil, err
    }
    return &sessionAuditLog, nil
}

func (s *LogSessionAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*SessionAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var sessionAuditLogs []*SessionAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var sessionAuditLog SessionAuditLog
        err = json.Unmarshal(queryResponse.Value, &sessionAuditLog)
        if err != nil {
            return nil, err
        }
        sessionAuditLogs = append(sessionAuditLogs, &sessionAuditLog)
    }
    return sessionAuditLogs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogSessionAudit{})
    if err != nil {
        fmt.Printf("Error creating LogSessionAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogSessionAudit chaincode: %v", err)
    }
}
EOF
            ;;
        LogConnectionAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogConnectionAudit struct {
    contractapi.Contract
}

type ConnectionAuditLog struct {
    EntityID  string `json:"entityID"`
    AntennaID string `json:"antennaID"`
    Action    string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogConnectionAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogConnectionAudit) Log(ctx contractapi.TransactionContextInterface, entityID, antennaID, action string) error {
    connectionAuditLog := ConnectionAuditLog{
        EntityID:  entityID,
        AntennaID: antennaID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    connectionAuditLogJSON, err := json.Marshal(connectionAuditLog)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, connectionAuditLogJSON)
}

func (s *LogConnectionAudit) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*ConnectionAuditLog, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("connection audit log %s does not exist", entityID)
    }
    var connectionAuditLog ConnectionAuditLog
    err = json.Unmarshal(assetJSON, &connectionAuditLog)
    if err != nil {
        return nil, err
    }
    return &connectionAuditLog, nil
}

func (s *LogConnectionAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*ConnectionAuditLog, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var connectionAuditLogs []*ConnectionAuditLog
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var connectionAuditLog ConnectionAuditLog
        err = json.Unmarshal(queryResponse.Value, &connectionAuditLog)
        if err != nil {
            return nil, err
        }
        connectionAuditLogs = append(connectionAuditLogs, &connectionAuditLog)
    }
    return connectionAuditLogs, nil
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
    chaincode, err := contractapi.NewChaincode(&LogConnectionAudit{})
    if err != nil {
        fmt.Printf("Error creating LogConnectionAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogConnectionAudit chaincode: %v", err)
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

echo "Generated chaincode for ${#contracts[@]} contracts in part 7:"
for contract in "${contracts[@]}"; do
    if [ -f "chaincode/$contract/chaincode.go" ]; then
        echo " - $contract: OK"
    else
        echo " - $contract: Failed"
    fi
done
