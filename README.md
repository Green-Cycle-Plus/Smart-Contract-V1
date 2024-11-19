# Smart-Contract-V1

### Documentation of Core Contracts Functions

### Waste Management Contract 

#### Contract Overview

The `WasteManagement` contract facilitates interactions between users (who generate waste), recyclers (who collect and recycle), and collectors (who physically collect the waste).

#### Core Functions

1. **User Registration**
   - **Function**: `createUser()`
   - **Description**: Registers a new user in the system.
   - **Interaction**: Call this method from the user's address.

2. **Set User Location**
   - **Function**: `setUserLocation(int32 latitude, int32 longitude)`
   - **Description**: Sets the geographical location of the user.
   - **Interaction**: Call this method after registering as a user.

3. **Recycler Registration**
   - **Function**: `createRecycler(address _recyclerAddress, string memory _location, uint256 _rating)`
   - **Description**: Registers a new recycler.
   - **Interaction**: Call this method from the recycler's address.

4. **Create Offer**
   - **Function**: `createOffer(address _recyclerAddress,string memory _wasteType,uint256 _pricePerKg,uint256 _minQuantity)`
   - **Description**: Allows recyclers to create offers for specific types of waste.
   - **Interaction**: Call this method from the recycler's address after registering.

5. **Make Collection Request**
   - **Function**: `makeRequest(address _recyclerAddress,string memory _wasteType,uint256 _weight,uint256 _price)`
   - **Description**: Users can create requests for collection from recyclers.
   - **Interaction**: Call this method from the user's address.

6. **Accept Collection Request**
   - **Function**: `acceptRequest(uint256 _requestID,address _collectorAddress)`
   - **Description**: Recyclers can accept requests made by users.
   - **Interaction**: Call this method from the recycler's address.

7. **Confirm Collection Completion**
   - **Function**: `confirmRequest(uint256 _requestID)`
   - **Description**: Collectors confirm that they have completed the collection.
   - **Interaction**: Call this method from the collector's address.

8. **Cancel Collection Request**
   - **Function**: `cancelRequestAndRefund(uint256 _requestID)`
   - **Description**: Allows authorized parties (recyclers or collectors) to cancel requests.
   - **Interaction**: Call this method from either the recycler’s or collector’s address.

### Escrow Contract 

#### Contract Overview

- **Purpose**: The `EscrowContract` manages financial transactions securely between parties involved in waste collection. It holds payments until specific conditions are met (e.g., confirmation of waste collection).
- **Key Features**:
  - Creation of escrows with payment.
  - Release of payments upon confirmation.
  - Refunds in case of disputes or failures.

#### Functions

1. **createEscrow**
   - **Description**: Creates a new escrow account and holds payment from a recycler.
   - **Parameters**:
     - `_payee`: The address of the collector who will receive payment.
   - **Returns**: The ID of the created escrow.
   - **Reverts**: If no payment is sent (`InvalidAmount`).

2. **releaseEscrow**
   - **Description**: Releases funds from an escrow account to the payee after collection confirmation.
   - **Parameters**:
     - `escrowId`: The ID of the escrow being released.
   - **Reverts**: If called by anyone other than the payer (`Unauthorized`), if not funded (`NotFunded`), or if already released (`AlreadyReleased`).

3. **refundEscrow**
   - **Description**: Allows the payer to refund their payment in case of collection failure or disputes.
   - **Parameters**:
     - `escrowId`: The ID of the escrow being refunded.
   - **Reverts**: If called by anyone other than the payer (`Unauthorized`), if not funded (`NotFunded`), if already released (`AlreadyReleased`), or if already refunded (`AlreadyRefunded`).

#### Events

- **EscrowCreated**: Emitted when a new escrow is created.
- **EscrowReleased**: Emitted when an escrow's funds are released.
- **EscrowRefunded**: Emitted when an escrow's funds are refunded.

### How to Interact with Functions

1. **Creating an Escrow**:
   - Call `createEscrow(payeeAddress)` with an appropriate Ether value sent along with it.

2. **Releasing Funds**:
   - Call `releaseEscrow(escrowId)` from the payer's address after confirming collection.

3. **Requesting a Refund**:
   - Call `refundEscrow(escrowId)` from the payer's address in case of issues with collection.

This documentation provides clear guidance on how to use and interact with `EscrowContract`


### Marketplace Contract 


