// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./interfaces/IEscrow.sol";

contract MarketPlaceContract {
    using ECDSA for bytes32;

    enum OrderStatus {
        PROCESSING,
        IN_TRANSIT,
        DELIVERED,
        CANCELLED
    }

    struct Category {
        uint id;
        string name;
    }

    struct Product {
        uint id;
        uint categoryId; // Link to dynamic category
        uint price;
        uint quantity;
        address recycler;
        bool isActive;
        string ipfsHash; // Off-chain storage for Name/descriptions/images
    }

    struct Order {
        uint orderId;
        uint[] productIds;
        address buyer;
        uint[] quantities;
        uint totalAmount;
        OrderStatus status;
        bytes32 orderHash;
    }

    IEscrow public escrowContract;

    mapping(uint => Category) public categories;
    uint[] public categoryIds;
    uint public totalCategory;

    uint public productCount;
    mapping(uint => Product) public products;
    mapping(address => uint[]) public recyclerProducts;
    mapping(address => uint256) public recyclerBalances;

    mapping(uint => Order) public orders;
    uint public orderCount;

    address public owner;

    // Events
    event CategoryAdded(uint indexed categoryId, string name);
    event CategoryUpdated(uint indexed categoryId, string name);
    event ProductListed(
        uint indexed productId,
        address indexed recycler,
        uint _categoryId,
        uint _price,
        uint _quantity,
        string _ipfsHash
    );
    event ProductPurchased(
        uint indexed productId,
        address indexed buyer,
        uint orderId
    );

    event OrderCreated(uint orderid, address buyer, uint totalAmount);
    event OrderDelivered(uint indexed orderId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor(address _escrowContract) {
        require(_escrowContract != address(0), "Invalid Address.");
        owner = msg.sender;
        escrowContract = IEscrow(_escrowContract);
    }

    // Category management functions

    function addCategory(string memory _name) public onlyOwner {
        uint categoryId = totalCategory++;
        categories[categoryId] = Category(categoryId, _name);
        categoryIds.push(categoryId);
        emit CategoryAdded(categoryId, _name);
    }

    function updateCategory(
        uint _categoryId,
        string memory _name
    ) public onlyOwner {
        Category storage category = categories[_categoryId];
        require(category.id == _categoryId, "Category does not exist");
        category.name = _name;
        emit CategoryUpdated(_categoryId, _name);
    }

    function getCategories() public view returns (Category[] memory) {
        Category[] memory activeCategories = new Category[](categoryIds.length);
        return activeCategories;
    }

    // Function for recyclers to list a new product.
    function listProduct(
        uint _categoryId,
        uint _price,
        uint _quantity,
        string memory _ipfsHash //Contains IPFS Hash of Name/description/image etc
    ) public {
        require(_quantity > 0, "Quantity must be greater than zero");
        require(_price > 0, "Invalid Price");

        productCount++;
        products[productCount] = Product({
            id: productCount,
            categoryId: _categoryId,
            price: _price,
            quantity: _quantity,
            recycler: msg.sender,
            isActive: true,
            ipfsHash: _ipfsHash
        });

        recyclerProducts[msg.sender].push(productCount);
        emit ProductListed(
            productCount,
            msg.sender,
            _categoryId,
            _price,
            _quantity,
            _ipfsHash
        );
    }

    // function purchaseProduct(uint _productId, uint _quantity) public payable {
    //     Product storage product = products[_productId];
    //     require(product.isActive, "Product is not available");
    //     require(product.quantity >= _quantity, "Not enough product quantity");

    //     uint totalprice = product.price * _quantity;
    //     uint256 userBal = msg.sender.balance;

    //     require(userBal >= totalprice, "Insufficient Funds");
    //     require(msg.value >= totalprice, "Insufficient Ether sent");

    //     //Increase recycle Balance
    //     recyclerBalances[product.recycler] += totalprice;

    //     if (msg.value > totalprice) {
    //         payable(msg.sender).transfer(msg.value - totalprice);
    //     }

    //     product.quantity -= _quantity;

    //     orderCount++;
    //     orders[orderCount] = Order({
    //         orderId: orderCount,
    //         productId: _productId,
    //         buyer: msg.sender,
    //         quantity: _quantity,
    //         totalprice: totalprice,
    //         status: OrderStatus.PROCESSING
    //     });
    //     emit ProductPurchased(_productId, msg.sender, orderCount);
    // }

    // Place order without loops, using signature verification
    function placeOrder(
        uint[] calldata _productIds,
        uint[] calldata _quantities,
        uint _totalAmount,
        bytes32 _orderHash, //Hash of the ProductIds, Quatities, Total Amount and Buyer Address.
        bytes calldata _signature //A signed message by the buy that authorizes this purchase. Like an agreement buyer agrees.
    ) external payable {
        require(
            _productIds.length == _quantities.length,
            "Product and quantity mismatch"
        );
        require(msg.value >= _totalAmount, "Insufficient payment for order");

        // Verify the order hash and signature
        bytes32 computedHash = keccak256(
            abi.encodePacked(_productIds, _quantities, _totalAmount, msg.sender)
        );
        require(computedHash == _orderHash, "Invalid order hash");

        // Manually create the Ethereum Signed Message hash
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", computedHash)
        );

        // Recover the signer using the signed hash and signature
        address signer = ECDSA.recover(ethSignedHash, _signature);
        require(signer == msg.sender, "Signature verification failed");

        // Proceed with order storage and escrow creation
        orderCount++;
        orders[orderCount] = Order({
            orderId: orderCount,
            productIds: _productIds,
            buyer: msg.sender,
            quantities: _quantities,
            totalAmount: _totalAmount,
            status: OrderStatus.PROCESSING,
            orderHash: _orderHash
        });

        // Create a single escrow for this order
        escrowContract.createEscrow{value: _totalAmount}(msg.sender);

        emit OrderCreated(orderCount, msg.sender, _totalAmount);
    }

    // Buyer confirms delivery to release funds
    function confirmDelivery(uint _orderId) external {
        Order storage order = orders[_orderId];
        require(order.buyer != address(0), "Order does not exist");
        require(order.buyer == msg.sender, "Only buyer can confirm delivery");
        require(order.status != OrderStatus.DELIVERED, "Order already confirmed as delivered");

        order.status = OrderStatus.DELIVERED;

        // Release funds from escrow
        escrowContract.releaseEscrow(_orderId);

        emit DeliveryConfirmed(_orderId);
    }

    function confirmOrderDelivery(uint _orderId) public {
        Order storage order = orders[_orderId];
        require(order.buyer != address(0), "Order does not exist");
        order.status = OrderStatus.DELIVERED;
        emit OrderDelivered(_orderId);
    }
}
