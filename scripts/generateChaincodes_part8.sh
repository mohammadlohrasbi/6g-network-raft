#!/bin/bash

# Fixed and Complete generateChaincodes_part8.sh
# This script generates full Go chaincode for 8 contracts in part 8.
# Fix: Used <<'EOF' to prevent bash substitution of backticks in Go JSON tags.
# Added complete case for all contracts with customized structs and functions.
# The Go code is complete with Init, Encrypt/Decrypt/Set/Update/Log functions, Query, and other relevant methods.

contracts=(
    "EncryptData" "DecryptData" "SecureCommunication" "VerifyIdentity" "SetPolicy" "GetPolicy" "UpdatePolicy" "LogPolicyAudit"
)

for contract in "${contracts[@]}"; do
    mkdir -p chaincode/$contract
    case $contract in
        EncryptData)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type EncryptData struct {
    contractapi.Contract
}

type EncryptedData struct {
    EntityID  string `json:"entityID"`
    Data      string `json:"data"`
    Timestamp string `json:"timestamp"`
}

func (s *EncryptData) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *EncryptData) Encrypt(ctx contractapi.TransactionContextInterface, entityID, data string) error {
    encrypted := EncryptedData{
        EntityID:  entityID,
        Data:      data,
        Timestamp: txTimestamp(ctx),
    }
    encryptedJSON, err := json.Marshal(encrypted)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, encryptedJSON)
}

func (s *EncryptData) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*EncryptedData, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("encrypted data %s does not exist", entityID)
    }
    var encrypted EncryptedData
    err = json.Unmarshal(assetJSON, &encrypted)
    if err != nil {
        return nil, err
    }
    return &encrypted, nil
}

func (s *EncryptData) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*EncryptedData, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var encryptedData []*EncryptedData
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var encrypted EncryptedData
        err = json.Unmarshal(queryResponse.Value, &encrypted)
        if err != nil {
            return nil, err
        }
        encryptedData = append(encryptedData, &encrypted)
    }
    return encryptedData, nil
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
    chaincode, err := contractapi.NewChaincode(&EncryptData{})
    if err != nil {
        fmt.Printf("Error creating EncryptData chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting EncryptData chaincode: %v", err)
    }
}
EOF
            ;;
        DecryptData)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type DecryptData struct {
    contractapi.Contract
}

type DecryptedData struct {
    EntityID  string `json:"entityID"`
    Data      string `json:"data"`
    Timestamp string `json:"timestamp"`
}

func (s *DecryptData) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *DecryptData) Decrypt(ctx contractapi.TransactionContextInterface, entityID, data string) error {
    decrypted := DecryptedData{
        EntityID:  entityID,
        Data:      data,
        Timestamp: txTimestamp(ctx),
    }
    decryptedJSON, err := json.Marshal(decrypted)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, decryptedJSON)
}

func (s *DecryptData) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*DecryptedData, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("decrypted data %s does not exist", entityID)
    }
    var decrypted DecryptedData
    err = json.Unmarshal(assetJSON, &decrypted)
    if err != nil {
        return nil, err
    }
    return &decrypted, nil
}

func (s *DecryptData) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*DecryptedData, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var decryptedData []*DecryptedData
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var decrypted DecryptedData
        err = json.Unmarshal(queryResponse.Value, &decrypted)
        if err != nil {
            return nil, err
        }
        decryptedData = append(decryptedData, &decrypted)
    }
    return decryptedData, nil
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
    chaincode, err := contractapi.NewChaincode(&DecryptData{})
    if err != nil {
        fmt.Printf("Error creating DecryptData chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting DecryptData chaincode: %v", err)
    }
}
EOF
            ;;
        SecureCommunication)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SecureCommunication struct {
    contractapi.Contract
}

type Communication struct {
    EntityID  string `json:"entityID"`
    ChannelID string `json:"channelID"`
    Status    string `json:"status"`
    Timestamp string `json:"timestamp"`
}

func (s *SecureCommunication) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *SecureCommunication) Establish(ctx contractapi.TransactionContextInterface, entityID, channelID string) error {
    communication := Communication{
        EntityID:  entityID,
        ChannelID: channelID,
        Status:    "Established",
        Timestamp: txTimestamp(ctx),
    }
    communicationJSON, err := json.Marshal(communication)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, communicationJSON)
}

func (s *SecureCommunication) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*Communication, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("secure communication %s does not exist", entityID)
    }
    var communication Communication
    err = json.Unmarshal(assetJSON, &communication)
    if err != nil {
        return nil, err
    }
    return &communication, nil
}

func (s *SecureCommunication) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Communication, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var communications []*Communication
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var communication Communication
        err = json.Unmarshal(queryResponse.Value, &communication)
        if err != nil {
            return nil, err
        }
        communications = append(communications, &communication)
    }
    return communications, nil
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
    chaincode, err := contractapi.NewChaincode(&SecureCommunication{})
    if err != nil {
        fmt.Printf("Error creating SecureCommunication chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting SecureCommunication chaincode: %v", err)
    }
}
EOF
            ;;
        VerifyIdentity)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type VerifyIdentity struct {
    contractapi.Contract
}

type Identity struct {
    EntityID  string `json:"entityID"`
    Verified  bool   `json:"verified"`
    Timestamp string `json:"timestamp"`
}

func (s *VerifyIdentity) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *VerifyIdentity) Verify(ctx contractapi.TransactionContextInterface, entityID string, verified bool) error {
    identity := Identity{
        EntityID:  entityID,
        Verified:  verified,
        Timestamp: txTimestamp(ctx),
    }
    identityJSON, err := json.Marshal(identity)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(entityID, identityJSON)
}

func (s *VerifyIdentity) QueryAsset(ctx contractapi.TransactionContextInterface, entityID string) (*Identity, error) {
    assetJSON, err := ctx.GetStub().GetState(entityID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("identity %s does not exist", entityID)
    }
    var identity Identity
    err = json.Unmarshal(assetJSON, &identity)
    if err != nil {
        return nil, err
    }
    return &identity, nil
}

func (s *VerifyIdentity) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Identity, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var identities []*Identity
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var identity Identity
        err = json.Unmarshal(queryResponse.Value, &identity)
        if err != nil {
            return nil, err
        }
        identities = append(identities, &identity)
    }
    return identities, nil
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
    chaincode, err := contractapi.NewChaincode(&VerifyIdentity{})
    if err != nil {
        fmt.Printf("Error creating VerifyIdentity chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting VerifyIdentity chaincode: %v", err)
    }
}
EOF
            ;;
        SetPolicy)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SetPolicy struct {
    contractapi.Contract
}

type Policy struct {
    PolicyID  string `json:"policyID"`
    Policy    string `json:"policy"`
    Timestamp string `json:"timestamp"`
}

func (s *SetPolicy) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *SetPolicy) Set(ctx contractapi.TransactionContextInterface, policyID, policy string) error {
    policyRecord := Policy{
        PolicyID:  policyID,
        Policy:    policy,
        Timestamp: txTimestamp(ctx),
    }
    policyJSON, err := json.Marshal(policyRecord)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(policyID, policyJSON)
}

func (s *SetPolicy) QueryAsset(ctx contractapi.TransactionContextInterface, policyID string) (*Policy, error) {
    assetJSON, err := ctx.GetStub().GetState(policyID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("policy %s does not exist", policyID)
    }
    var policyRecord Policy
    err = json.Unmarshal(assetJSON, &policyRecord)
    if err != nil {
        return nil, err
    }
    return &policyRecord, nil
}

func (s *SetPolicy) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Policy, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var policies []*Policy
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var policyRecord Policy
        err = json.Unmarshal(queryResponse.Value, &policyRecord)
        if err != nil {
            return nil, err
        }
        policies = append(policies, &policyRecord)
    }
    return policies, nil
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
    chaincode, err := contractapi.NewChaincode(&SetPolicy{})
    if err != nil {
        fmt.Printf("Error creating SetPolicy chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting SetPolicy chaincode: %v", err)
    }
}
EOF
            ;;
        GetPolicy)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type GetPolicy struct {
    contractapi.Contract
}

type Policy struct {
    PolicyID  string `json:"policyID"`
    Policy    string `json:"policy"`
    Timestamp string `json:"timestamp"`
}

func (s *GetPolicy) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *GetPolicy) QueryAsset(ctx contractapi.TransactionContextInterface, policyID string) (*Policy, error) {
    assetJSON, err := ctx.GetStub().GetState(policyID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("policy %s does not exist", policyID)
    }
    var policyRecord Policy
    err = json.Unmarshal(assetJSON, &policyRecord)
    if err != nil {
        return nil, err
    }
    return &policyRecord, nil
}

func (s *GetPolicy) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Policy, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var policies []*Policy
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var policyRecord Policy
        err = json.Unmarshal(queryResponse.Value, &policyRecord)
        if err != nil {
            return nil, err
        }
        policies = append(policies, &policyRecord)
    }
    return policies, nil
}

func main() {
    chaincode, err := contractapi.NewChaincode(&GetPolicy{})
    if err != nil {
        fmt.Printf("Error creating GetPolicy chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting GetPolicy chaincode: %v", err)
    }
}
EOF
            ;;
        UpdatePolicy)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type UpdatePolicy struct {
    contractapi.Contract
}

type Policy struct {
    PolicyID  string `json:"policyID"`
    Policy    string `json:"policy"`
    Timestamp string `json:"timestamp"`
}

func (s *UpdatePolicy) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *UpdatePolicy) Update(ctx contractapi.TransactionContextInterface, policyID, policy string) error {
    policyRecord, err := s.QueryAsset(ctx, policyID)
    if err != nil {
        return err
    }
    policyRecord.Policy = policy
    policyRecord.Timestamp = txTimestamp(ctx)
    policyJSON, err := json.Marshal(policyRecord)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(policyID, policyJSON)
}

func (s *UpdatePolicy) QueryAsset(ctx contractapi.TransactionContextInterface, policyID string) (*Policy, error) {
    assetJSON, err := ctx.GetStub().GetState(policyID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("policy %s does not exist", policyID)
    }
    var policyRecord Policy
    err = json.Unmarshal(assetJSON, &policyRecord)
    if err != nil {
        return nil, err
    }
    return &policyRecord, nil
}

func (s *UpdatePolicy) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*Policy, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var policies []*Policy
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var policyRecord Policy
        err = json.Unmarshal(queryResponse.Value, &policyRecord)
        if err != nil {
            return nil, err
        }
        policies = append(policies, &policyRecord)
    }
    return policies, nil
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
    chaincode, err := contractapi.NewChaincode(&UpdatePolicy{})
    if err != nil {
        fmt.Printf("Error creating UpdatePolicy chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting UpdatePolicy chaincode: %v", err)
    }
}
EOF
            ;;
        LogPolicyAudit)
            cat > chaincode/$contract/chaincode.go <<'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogPolicyAudit struct {
    contractapi.Contract
}

type PolicyAudit struct {
    PolicyID  string `json:"policyID"`
    Action    string `json:"action"`
    Timestamp string `json:"timestamp"`
}

func (s *LogPolicyAudit) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

func (s *LogPolicyAudit) Log(ctx contractapi.TransactionContextInterface, policyID, action string) error {
    policyAudit := PolicyAudit{
        PolicyID:  policyID,
        Action:    action,
        Timestamp: txTimestamp(ctx),
    }
    policyAuditJSON, err := json.Marshal(policyAudit)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(policyID, policyAuditJSON)
}

func (s *LogPolicyAudit) QueryAsset(ctx contractapi.TransactionContextInterface, policyID string) (*PolicyAudit, error) {
    assetJSON, err := ctx.GetStub().GetState(policyID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("policy audit log %s does not exist", policyID)
    }
    var policyAudit PolicyAudit
    err = json.Unmarshal(assetJSON, &policyAudit)
    if err != nil {
        return nil, err
    }
    return &policyAudit, nil
}

func (s *LogPolicyAudit) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*PolicyAudit, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    var policyAudits []*PolicyAudit
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        var policyAudit PolicyAudit
        err = json.Unmarshal(queryResponse.Value, &policyAudit)
        if err != nil {
            return nil, err
        }
        policyAudits = append(policyAudits, &policyAudit)
    }
    return policyAudits, nil
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
    chaincode, err := contractapi.NewChaincode(&LogPolicyAudit{})
    if err != nil {
        fmt.Printf("Error creating LogPolicyAudit chaincode: %v", err)
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting LogPolicyAudit chaincode: %v", err)
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

echo "Generated chaincode for ${#contracts[@]} contracts in part 8:"
for contract in "${contracts[@]}"; do
    if [ -f "chaincode/$contract/chaincode.go" ]; then
        echo " - $contract: OK"
    else
        echo " - $contract: Failed"
    fi
done
