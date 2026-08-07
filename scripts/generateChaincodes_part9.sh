#!/bin/bash

# Fixed and Complete generateChaincodes_part9.sh
# This script generates full Go chaincode for 9 contracts in part 9.
# Fix: Used <<'EOF' to prevent bash substitution of backticks in Go JSON tags.
# Added complete case for all contracts with customized structs and functions.
# The Go code is complete with Init, Update/Record/Log functions, Query, and other relevant methods.

set -e  # Stop on first error


contracts=(
    "ManageNetwork" "ManageAntenna" "ManageIoTDevice" "ManageUser" "MonitorTraffic" 
    "MonitorInterference" "MonitorResourceUsage" "LogSecurityEvent" "LogAccessControl"
)

for contract in "${contracts[@]}"; do
    mkdir -p chaincode/$contract
    case $contract in
        ManageNetwork)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ManageNetwork struct {
    contractapi.Contract
}

type Network struct {
    NetworkID string `json:"networkID"`
    Status    string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *ManageNetwork) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *ManageNetwork) UpdateNetworkStatus(ctx contractapi.TransactionContextInterface, networkID, status string) error {
    network := Network{
        NetworkID: networkID,
        Status:    status,
        Timestamp: txTimestamp(ctx),
    }
    networkJSON, err := json.Marshal(network)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, networkJSON)
}

func (s *ManageNetwork) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*Network, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("network %s does not exist", networkID)
    }
    var network Network
    err = json.Unmarshal(assetJSON, &network)
    if err != nil {
        return nil, err
    }
    return &network, nil
}

func (s *ManageNetwork) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Network, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var networks []*Network
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var network Network
        err = json.Unmarshal(queryResponse.Value, &network)
        if err != nil {
            return nil, err
        }
        networks = append(networks, &network)
    }
    return networks, nil
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
    chaincode, err := contractapi.NewChaincode(&ManageNetwork{})
    if err != nil {
        fmt.Printf("Error creating ManageNetwork chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting ManageNetwork chaincode: %v", err)
    }
}
EOF
            ;;
        ManageAntenna)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ManageAntenna struct {
    contractapi.Contract
}

type Antenna struct {
    AntennaID string `json:"antennaID"`
    Status    string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *ManageAntenna) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *ManageAntenna) UpdateAntennaStatus(ctx contractapi.TransactionContextInterface, antennaID, status string) error {
    antenna := Antenna{
        AntennaID: antennaID,
        Status:    status,
        Timestamp: txTimestamp(ctx),
    }
    antennaJSON, err := json.Marshal(antenna)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(antennaID, antennaJSON)
}

func (s *ManageAntenna) QueryAsset(ctx contractapi.TransactionContextInterface, antennaID string) (*Antenna, error) {
    assetJSON, err := ctx.GetStub().GetState(antennaID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("antenna %s does not exist", antennaID)
    }
    var antenna Antenna
    err = json.Unmarshal(assetJSON, &antenna)
    if err != nil {
        return nil, err
    }
    return &antenna, nil
}

func (s *ManageAntenna) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Antenna, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var antennas []*Antenna
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var antenna Antenna
        err = json.Unmarshal(queryResponse.Value, &antenna)
        if err != nil {
            return nil, err
        }
        antennas = append(antennas, &antenna)
    }
    return antennas, nil
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
    chaincode, err := contractapi.NewChaincode(&ManageAntenna{})
    if err != nil {
        fmt.Printf("Error creating ManageAntenna chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting ManageAntenna chaincode: %v", err)
    }
}
EOF
            ;;
        ManageIoTDevice)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ManageIoTDevice struct {
    contractapi.Contract
}

type IoTDevice struct {
    DeviceID  string `json:"deviceID"`
    Status    string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *ManageIoTDevice) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *ManageIoTDevice) UpdateDeviceStatus(ctx contractapi.TransactionContextInterface, deviceID, status string) error {
    iotDevice := IoTDevice{
        DeviceID:  deviceID,
        Status:    status,
        Timestamp: txTimestamp(ctx),
    }
    iotDeviceJSON, err := json.Marshal(iotDevice)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotDeviceJSON)
}

func (s *ManageIoTDevice) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTDevice, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT device %s does not exist", deviceID)
    }
    var iotDevice IoTDevice
    err = json.Unmarshal(assetJSON, &iotDevice)
    if err != nil {
        return nil, err
    }
    return &iotDevice, nil
}

func (s *ManageIoTDevice) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTDevice, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var iotDevices []*IoTDevice
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var iotDevice IoTDevice
        err = json.Unmarshal(queryResponse.Value, &iotDevice)
        if err != nil {
            return nil, err
        }
        iotDevices = append(iotDevices, &iotDevice)
    }
    return iotDevices, nil
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
    chaincode, err := contractapi.NewChaincode(&ManageIoTDevice{})
    if err != nil {
        fmt.Printf("Error creating ManageIoTDevice chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting ManageIoTDevice chaincode: %v", err)
    }
}
EOF
            ;;
        ManageUser)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ManageUser struct {
    contractapi.Contract
}

type User struct {
    UserID    string `json:"userID"`
    Status    string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *ManageUser) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *ManageUser) UpdateUserStatus(ctx contractapi.TransactionContextInterface, userID, status string) error {
    user := User{
        UserID:    userID,
        Status:    status,
        Timestamp: txTimestamp(ctx),
    }
    userJSON, err := json.Marshal(user)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userJSON)
}

func (s *ManageUser) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*User, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user %s does not exist", userID)
    }
    var user User
    err = json.Unmarshal(assetJSON, &user)
    if err != nil {
        return nil, err
    }
    return &user, nil
}

func (s *ManageUser) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*User, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var users []*User
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var user User
        err = json.Unmarshal(queryResponse.Value, &user)
        if err != nil {
            return nil, err
        }
        users = append(users, &user)
    }
    return users, nil
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
    chaincode, err := contractapi.NewChaincode(&ManageUser{})
    if err != nil {
        fmt.Printf("Error creating ManageUser chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting ManageUser chaincode: %v", err)
    }
}
EOF
            ;;
        MonitorTraffic)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type MonitorTraffic struct {
    contractapi.Contract
}

type Traffic struct {
    NetworkID string `json:"networkID"`
    Traffic   string `json:"traffic"`
    Timestamp string `json:"timestamp"`
}

func (s *MonitorTraffic) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *MonitorTraffic) RecordTraffic(ctx contractapi.TransactionContextInterface, networkID, traffic string) error {
    trafficRecord := Traffic{
        NetworkID: networkID,
        Traffic:   traffic,
        Timestamp: txTimestamp(ctx),
    }
    trafficJSON, err := json.Marshal(trafficRecord)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, trafficJSON)
}

func (s *MonitorTraffic) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*Traffic, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("traffic %s does not exist", networkID)
    }
    var trafficRecord Traffic
    err = json.Unmarshal(assetJSON, &trafficRecord)
    if err != nil {
        return nil, err
    }
    return &trafficRecord, nil
}

func (s *MonitorTraffic) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Traffic, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var traffics []*Traffic
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var trafficRecord Traffic
        err = json.Unmarshal(queryResponse.Value, &trafficRecord)
        if err != nil {
            return nil, err
        }
        traffics = append(traffics, &trafficRecord)
    }
    return traffics, nil
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
    chaincode, err := contractapi.NewChaincode(&MonitorTraffic{})
    if err != nil {
        fmt.Printf("Error creating MonitorTraffic chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting MonitorTraffic chaincode: %v", err)
    }
}
EOF
            ;;
        MonitorInterference)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type MonitorInterference struct {
    contractapi.Contract
}

type Interference struct {
    NetworkID        string `json:"networkID"`
    InterferenceLevel string `json:"interferenceLevel"`
    Timestamp        string `json:"timestamp"`
}

func (s *MonitorInterference) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *MonitorInterference) RecordInterference(ctx contractapi.TransactionContextInterface, networkID, interferenceLevel string) error {
    interference := Interference{
        NetworkID:        networkID,
        InterferenceLevel: interferenceLevel,
        Timestamp:        txTimestamp(ctx),
    }
    interferenceJSON, err := json.Marshal(interference)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(networkID, interferenceJSON)
}

func (s *MonitorInterference) QueryAsset(ctx contractapi.TransactionContextInterface, networkID string) (*Interference, error) {
    assetJSON, err := ctx.GetStub().GetState(networkID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("interference %s does not exist", networkID)
    }
    var interference Interference
    err = json.Unmarshal(assetJSON, &interference)
    if err != nil {
        return nil, err
    }
    return &interference, nil
}

func (s *MonitorInterference) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Interference, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var interferences []*Interference
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var interference Interference
        err = json.Unmarshal(queryResponse.Value, &interference)
        if err != nil {
            return nil, err
        }
        interferences = append(interferences, &interference)
    }
    return interferences, nil
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
    chaincode, err := contractapi.NewChaincode(&MonitorInterference{})
    if err != nil {
        fmt.Printf("Error creating MonitorInterference chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting MonitorInterference chaincode: %v", err)
    }
}
EOF
            ;;
        MonitorResourceUsage)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type MonitorResourceUsage struct {
    contractapi.Contract
}

type ResourceUsage struct {
    EntityID  string `json:"entityID"`
    Resource  string `json:"resource"`
    Amount    string `json:"amount"`
    Timestamp string `json:"timestamp"`
}

func (s *MonitorResourceUsage) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *MonitorResourceUsage) RecordUsage(ctx contractapi.TransactionContextInterface, entityID, resource, amount string) error {
    resourceUsage := ResourceUsage{
        EntityID:  entityID,
        Resource:  resource,
        Amount:    amount,
        Timestamp: txTimestamp(ctx),
    }
    resourceUsageJSON, err := json.Marshal(resourceUsage)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, resourceUsageJSON)
}

func (s *MonitorResourceUsage) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*ResourceUsage, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("resource usage %s does not exist", entityID)
    }
    var resourceUsage ResourceUsage
    err = json.Unmarshal(assetJSON, &resourceUsage)
    if err != nil {
        return nil, err
    }
    return &resourceUsage, nil
}

func (s *MonitorResourceUsage) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*ResourceUsage, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var resourceUsages []*ResourceUsage
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var resourceUsage ResourceUsage
        err = json.Unmarshal(queryResponse.Value, &resourceUsage)
        if err != nil {
            return nil, err
        }
        resourceUsages = append(resourceUsages, &resourceUsage)
    }
    return resourceUsages, nil
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
    chaincode, err := contractapi.NewChaincode(&MonitorResourceUsage{})
    if err != nil {
        fmt.Printf("Error creating MonitorResourceUsage chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting MonitorResourceUsage chaincode: %v", err)
    }
}
EOF
            ;;
        LogSecurityEvent)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogSecurityEvent struct {
    contractapi.Contract
}

type SecurityEvent struct {
    EntityID  string `json:"entityID"`
    Event     string `json:"event"`
    Timestamp string `json:"timestamp"`
}

func (s *LogSecurityEvent) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogSecurityEvent) Log(ctx contractapi.TransactionContextInterface, entityID, event string) error {
    securityEvent := SecurityEvent{
        EntityID:  entityID,
        Event:     event,
        Timestamp: txTimestamp(ctx),
    }
    securityEventJSON, err := json.Marshal(securityEvent)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, securityEventJSON)
}

func (s *LogSecurityEvent) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*SecurityEvent, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("security event %s does not exist", entityID)
    }
    var securityEvent SecurityEvent
    err = json.Unmarshal(assetJSON, &securityEvent)
    if err != nil {
        return nil, err
    }
    return &securityEvent, nil
}

func (s *LogSecurityEvent) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*SecurityEvent, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var securityEvents []*SecurityEvent
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var securityEvent SecurityEvent
        err = json.Unmarshal(queryResponse.Value, &securityEvent)
        if err != nil {
            return nil, err
        }
        securityEvents = append(securityEvents, &securityEvent)
    }
    return securityEvents, nil
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
    chaincode, err := contractapi.NewChaincode(&LogSecurityEvent{})
    if err != nil {
        fmt.Printf("Error creating LogSecurityEvent chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogSecurityEvent chaincode: %v", err)
    }
}
EOF
            ;;
        LogAccessControl)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogAccessControl struct {
    contractapi.Contract
}

type AccessControl struct {
    EntityID  string `json:"entityID"`
    Action    string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogAccessControl) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogAccessControl) Log(ctx contractapi.TransactionContextInterface, entityID, action string) error {
    accessControl := AccessControl{
        EntityID:  entityID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    accessControlJSON, err := json.Marshal(accessControl)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, accessControlJSON)
}

func (s *LogAccessControl) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*AccessControl, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("access control %s does not exist", entityID)
    }
    var accessControl AccessControl
    err = json.Unmarshal(assetJSON, &accessControl)
    if err != nil {
        return nil, err
    }
    return &accessControl, nil
}

func (s *LogAccessControl) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*AccessControl, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var accessControls []*AccessControl
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var accessControl AccessControl
        err = json.Unmarshal(queryResponse.Value, &accessControl)
        if err != nil {
            return nil, err
        }
        accessControls = append(accessControls, &accessControl)
    }
    return accessControls, nil
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
    chaincode, err := contractapi.NewChaincode(&LogAccessControl{})
    if err != nil {
        fmt.Printf("Error creating LogAccessControl chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogAccessControl chaincode: %v", err)
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

echo "Generated chaincode for ${#contracts[@]} contracts in part 9:"
for contract in "${contracts[@]}"; do
    if [ -f "chaincode/$contract/chaincode.go" ]; then
        echo " - $contract: OK"
    else
        echo " - $contract: Failed"
    fi
done
