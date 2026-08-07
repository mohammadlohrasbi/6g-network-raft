#!/bin/bash

# Fixed and Complete generateChaincodes_part5.sh
# This script generates full Go chaincode for 9 contracts in part 5.
# Fix: Used <<'EOF' to  prevent bash substitution of backticks in Go JSON tags.
# Added complete case for all contracts with customized structs and functions based on fields from errors.
# The Go code is complete with Init, Authenticate/Register/Revoke/Assign functions, Query, and other relevant methods.

set -e  # Stop on first error


contracts=(
    "AuthenticateUser" "AuthenticateIoT" "ConnectUser" "ConnectIoT" "RegisterUser" "RegisterIoT" "RevokeUser" "RevokeIoT" "AssignRole"
)

for contract in "${contracts[@]}"; do
    mkdir -p chaincode/$contract
    case $contract in
        AuthenticateUser)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type AuthenticateUser struct {
    contractapi.Contract
}

type UserAuth struct {
    UserID string `json:"userID"`
    Token string `json:"token"`
    Timestamp string `json:"timestamp"`
}

func (s *AuthenticateUser) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *AuthenticateUser) Authenticate(ctx contractapi.TransactionContextInterface, userID, token string) error {
    userAuth := UserAuth{
        UserID: userID,
        Token: token,
        Timestamp: txTimestamp(ctx),
    }
    userAuthJSON, err := json.Marshal(userAuth)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userAuthJSON)
}

func (s *AuthenticateUser) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*UserAuth, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user authentication %s does not exist", userID)
    }
    var userAuth UserAuth
    err = json.Unmarshal(assetJSON, &userAuth)
    if err != nil {
        return nil, err
    }
    return &userAuth, nil
}

func (s *AuthenticateUser) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*UserAuth, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var userAuths []*UserAuth
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var userAuth UserAuth
        err = json.Unmarshal(queryResponse.Value, &userAuth)
        if err != nil {
            return nil, err
        }
        userAuths = append(userAuths, &userAuth)
    }
    return userAuths, nil
}

func (s *AuthenticateUser) ValidateToken(ctx contractapi.TransactionContextInterface, userID, token string) (bool, error) {
    userAuth, err := s.QueryAsset(ctx, userID)
    if err != nil {
        return false, err
    }
    return userAuth.Token == token, nil
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
    chaincode, err := contractapi.NewChaincode(&AuthenticateUser{})
    if err != nil {
        fmt.Printf("Error creating AuthenticateUser chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting AuthenticateUser chaincode: %v", err)
    }
}
EOF
            ;;
        AuthenticateIoT)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type AuthenticateIoT struct {
    contractapi.Contract
}

type IoTAuth struct {
    DeviceID string `json:"deviceID"`
    Token string `json:"token"`
    Timestamp string `json:"timestamp"`
}

func (s *AuthenticateIoT) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *AuthenticateIoT) Authenticate(ctx contractapi.TransactionContextInterface, deviceID, token string) error {
    iotAuth := IoTAuth{
        DeviceID: deviceID,
        Token: token,
        Timestamp: txTimestamp(ctx),
    }
    iotAuthJSON, err := json.Marshal(iotAuth)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotAuthJSON)
}

func (s *AuthenticateIoT) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTAuth, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT authentication %s does not exist", deviceID)
    }
    var iotAuth IoTAuth
    err = json.Unmarshal(assetJSON, &iotAuth)
    if err != nil {
        return nil, err
    }
    return &iotAuth, nil
}

func (s *AuthenticateIoT) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTAuth, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var iotAuths []*IoTAuth
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var iotAuth IoTAuth
        err = json.Unmarshal(queryResponse.Value, &iotAuth)
        if err != nil {
            return nil, err
        }
        iotAuths = append(iotAuths, &iotAuth)
    }
    return iotAuths, nil
}

func (s *AuthenticateIoT) ValidateToken(ctx contractapi.TransactionContextInterface, deviceID, token string) (bool, error) {
    iotAuth, err := s.QueryAsset(ctx, deviceID)
    if err != nil {
        return false, err
    }
    return iotAuth.Token == token, nil
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
    chaincode, err := contractapi.NewChaincode(&AuthenticateIoT{})
    if err != nil {
        fmt.Printf("Error creating AuthenticateIoT chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting AuthenticateIoT chaincode: %v", err)
    }
}
EOF
            ;;
        ConnectUser)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ConnectUser struct {
    contractapi.Contract
}

type UserConnection struct {
    UserID string `json:"userID"`
    AntennaID string `json:"antennaID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *ConnectUser) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *ConnectUser) Connect(ctx contractapi.TransactionContextInterface, userID, antennaID string) error {
    userConnection := UserConnection{
        UserID: userID,
        AntennaID: antennaID,
        Status: "Connected",
        Timestamp: txTimestamp(ctx),
    }
    userConnectionJSON, err := json.Marshal(userConnection)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userConnectionJSON)
}

func (s *ConnectUser) Disconnect(ctx contractapi.TransactionContextInterface, userID string) error {
    userConnection, err := s.QueryAsset(ctx, userID)
    if err != nil {
        return err
    }
    userConnection.Status = "Disconnected"
    userConnection.Timestamp = txTimestamp(ctx)
    userConnectionJSON, err := json.Marshal(userConnection)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userConnectionJSON)
}

func (s *ConnectUser) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*UserConnection, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user connection %s does not exist", userID)
    }
    var userConnection UserConnection
    err = json.Unmarshal(assetJSON, &userConnection)
    if err != nil {
        return nil, err
    }
    return &userConnection, nil
}

func (s *ConnectUser) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*UserConnection, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var userConnections []*UserConnection
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var userConnection UserConnection
        err = json.Unmarshal(queryResponse.Value, &userConnection)
        if err != nil {
            return nil, err
        }
        userConnections = append(userConnections, &userConnection)
    }
    return userConnections, nil
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
    chaincode, err := contractapi.NewChaincode(&ConnectUser{})
    if err != nil {
        fmt.Printf("Error creating ConnectUser chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting ConnectUser chaincode: %v", err)
    }
}
EOF
            ;;
        ConnectIoT)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ConnectIoT struct {
    contractapi.Contract
}

type IoTConnection struct {
    DeviceID string `json:"deviceID"`
    AntennaID string `json:"antennaID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *ConnectIoT) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *ConnectIoT) Connect(ctx contractapi.TransactionContextInterface, deviceID, antennaID string) error {
    iotConnection := IoTConnection{
        DeviceID: deviceID,
        AntennaID: antennaID,
        Status: "Connected",
        Timestamp: txTimestamp(ctx),
    }
    iotConnectionJSON, err := json.Marshal(iotConnection)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotConnectionJSON)
}

func (s *ConnectIoT) Disconnect(ctx contractapi.TransactionContextInterface, deviceID string) error {
    iotConnection, err := s.QueryAsset(ctx, deviceID)
    if err != nil {
        return err
    }
    iotConnection.Status = "Disconnected"
    iotConnection.Timestamp = txTimestamp(ctx)
    iotConnectionJSON, err := json.Marshal(iotConnection)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotConnectionJSON)
}

func (s *ConnectIoT) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTConnection, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT connection %s does not exist", deviceID)
    }
    var iotConnection IoTConnection
    err = json.Unmarshal(assetJSON, &iotConnection)
    if err != nil {
        return nil, err
    }
    return &iotConnection, nil
}

func (s *ConnectIoT) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTConnection, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var iotConnections []*IoTConnection
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var iotConnection IoTConnection
        err = json.Unmarshal(queryResponse.Value, &iotConnection)
        if err != nil {
            return nil, err
        }
        iotConnections = append(iotConnections, &iotConnection)
    }
    return iotConnections, nil
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
    chaincode, err := contractapi.NewChaincode(&ConnectIoT{})
    if err != nil {
        fmt.Printf("Error creating ConnectIoT chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting ConnectIoT chaincode: %v", err)
    }
}
EOF
            ;;
        RegisterUser)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type RegisterUser struct {
    contractapi.Contract
}

type UserRegistration struct {
    UserID string `json:"userID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *RegisterUser) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *RegisterUser) Register(ctx contractapi.TransactionContextInterface, userID, status string) error {
    userRegistration := UserRegistration{
        UserID: userID,
        Status: status,
        Timestamp: txTimestamp(ctx),
    }
    userRegistrationJSON, err := json.Marshal(userRegistration)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userRegistrationJSON)
}

func (s *RegisterUser) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*UserRegistration, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user registration %s does not exist", userID)
    }
    var userRegistration UserRegistration
    err = json.Unmarshal(assetJSON, &userRegistration)
    if err != nil {
        return nil, err
    }
    return &userRegistration, nil
}

func (s *RegisterUser) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*UserRegistration, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var userRegistrations []*UserRegistration
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var userRegistration UserRegistration
        err = json.Unmarshal(queryResponse.Value, &userRegistration)
        if err != nil {
            return nil, err
        }
        userRegistrations = append(userRegistrations, &userRegistration)
    }
    return userRegistrations, nil
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
    chaincode, err := contractapi.NewChaincode(&RegisterUser{})
    if err != nil {
        fmt.Printf("Error creating RegisterUser chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting RegisterUser chaincode: %v", err)
    }
}
EOF
            ;;
        RegisterIoT)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type RegisterIoT struct {
    contractapi.Contract
}

type IoTRegistration struct {
    DeviceID string `json:"deviceID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *RegisterIoT) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *RegisterIoT) Register(ctx contractapi.TransactionContextInterface, deviceID, status string) error {
    iotRegistration := IoTRegistration{
        DeviceID: deviceID,
        Status: status,
        Timestamp: txTimestamp(ctx),
    }
    iotRegistrationJSON, err := json.Marshal(iotRegistration)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotRegistrationJSON)
}

func (s *RegisterIoT) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTRegistration, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT registration %s does not exist", deviceID)
    }
    var iotRegistration IoTRegistration
    err = json.Unmarshal(assetJSON, &iotRegistration)
    if err != nil {
        return nil, err
    }
    return &iotRegistration, nil
}

func (s *RegisterIoT) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTRegistration, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var iotRegistrations []*IoTRegistration
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var iotRegistration IoTRegistration
        err = json.Unmarshal(queryResponse.Value, &iotRegistration)
        if err != nil {
            return nil, err
        }
        iotRegistrations = append(iotRegistrations, &iotRegistration)
    }
    return iotRegistrations, nil
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
    chaincode, err := contractapi.NewChaincode(&RegisterIoT{})
    if err != nil {
        fmt.Printf("Error creating RegisterIoT chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting RegisterIoT chaincode: %v", err)
    }
}
EOF
            ;;
        RevokeUser)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type RevokeUser struct {
    contractapi.Contract
}

type UserRevocation struct {
    UserID string `json:"userID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *RevokeUser) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *RevokeUser) Revoke(ctx contractapi.TransactionContextInterface, userID, status string) error {
    userRevocation := UserRevocation{
        UserID: userID,
        Status: status,
        Timestamp: txTimestamp(ctx),
    }
    userRevocationJSON, err := json.Marshal(userRevocation)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userRevocationJSON)
}

func (s *RevokeUser) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*UserRevocation, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user revocation %s does not exist", userID)
    }
    var userRevocation UserRevocation
    err = json.Unmarshal(assetJSON, &userRevocation)
    if err != nil {
        return nil, err
    }
    return &userRevocation, nil
}

func (s *RevokeUser) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*UserRevocation, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var userRevocations []*UserRevocation
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var userRevocation UserRevocation
        err = json.Unmarshal(queryResponse.Value, &userRevocation)
        if err != nil {
            return nil, err
        }
        userRevocations = append(userRevocations, &userRevocation)
    }
    return userRevocations, nil
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
    chaincode, err := contractapi.NewChaincode(&RevokeUser{})
    if err != nil {
        fmt.Printf("Error creating RevokeUser chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting RevokeUser chaincode: %v", err)
    }
}
EOF
            ;;
        RevokeIoT)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type RevokeIoT struct {
    contractapi.Contract
}

type IoTRevocation struct {
    DeviceID string `json:"deviceID"`
    Status string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *RevokeIoT) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *RevokeIoT) Revoke(ctx contractapi.TransactionContextInterface, deviceID, status string) error {
    iotRevocation := IoTRevocation{
        DeviceID: deviceID,
        Status: status,
        Timestamp: txTimestamp(ctx),
    }
    iotRevocationJSON, err := json.Marshal(iotRevocation)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(deviceID, iotRevocationJSON)
}

func (s *RevokeIoT) QueryAsset(ctx contractapi.TransactionContextInterface, deviceID string) (*IoTRevocation, error) {
    assetJSON, err := ctx.GetStub().GetState(deviceID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("IoT revocation %s does not exist", deviceID)
    }
    var iotRevocation IoTRevocation
    err = json.Unmarshal(assetJSON, &iotRevocation)
    if err != nil {
        return nil, err
    }
    return &iotRevocation, nil
}

func (s *RevokeIoT) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*IoTRevocation, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var iotRevocations []*IoTRevocation
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var iotRevocation IoTRevocation
        err = json.Unmarshal(queryResponse.Value, &iotRevocation)
        if err != nil {
            return nil, err
        }
        iotRevocations = append(iotRevocations, &iotRevocation)
    }
    return iotRevocations, nil
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
    chaincode, err := contractapi.NewChaincode(&RevokeIoT{})
    if err != nil {
        fmt.Printf("Error creating RevokeIoT chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting RevokeIoT chaincode: %v", err)
    }
}
EOF
            ;;
        AssignRole)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type AssignRole struct {
    contractapi.Contract
}

type RoleAssignment struct {
    UserID string `json:"userID"`
    Role string `json:"role"`
    Timestamp string `json:"timestamp"`
}

func (s *AssignRole) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *AssignRole) Assign(ctx contractapi.TransactionContextInterface, userID, role string) error {
    roleAssignment := RoleAssignment{
        UserID: userID,
        Role: role,
        Timestamp: txTimestamp(ctx),
    }
    roleAssignmentJSON, err := json.Marshal(roleAssignment)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, roleAssignmentJSON)
}

func (s *AssignRole) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*RoleAssignment, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("role assignment %s does not exist", userID)
    }
    var roleAssignment RoleAssignment
    err = json.Unmarshal(assetJSON, &roleAssignment)
    if err != nil {
        return nil, err
    }
    return &roleAssignment, nil
}

func (s *AssignRole) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*RoleAssignment, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var roleAssignments []*RoleAssignment
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var roleAssignment RoleAssignment
        err = json.Unmarshal(queryResponse.Value, &roleAssignment)
        if err != nil {
            return nil, err
        }
        roleAssignments = append(roleAssignments, &roleAssignment)
    }
    return roleAssignments, nil
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
    chaincode, err := contractapi.NewChaincode(&AssignRole{})
    if err != nil {
        fmt.Printf("Error creating AssignRole chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting AssignRole chaincode: %v", err)
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

echo "Generated chaincode for ${#contracts[@]} contracts in part 5:"
for contract in "${contracts[@]}"; do
    if [ -f "chaincode/$contract/chaincode.go" ]; then
        echo " - $contract: OK"
    else
        echo " - $contract: Failed"
    fi
done
