// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./interfaces/IEscrow.sol";
import "./libraries/ErrorLib.sol";
import "./libraries/CategoryLib.sol";
import "./libraries/ProductLib.sol";
import "./libraries/OrderLib.sol";

/**
 * @title MarketPlaceContract
 * @dev Marketplace contract for managing categories, products, and orders, including escrow management for the recyclers to upload their products.
 */
contract MarketPlaceContract {
    using ECDSA for bytes32;

    using CategoryLib for CategoryLib.CategoryStorage;
    using ProductLib for ProductLib.ProductStorage;
    using OrderLib for OrderLib.OrderStorage;

    CategoryLib.CategoryStorage categoryAction;
    ProductLib.ProductStorage productAction;
    OrderLib.OrderStorage orderAction;

    mapping(address => bool) public authorizedRecyclers;

    IEscrow public escrowContract;

    address public owner;

    // Events
    event LogFallback(address sender, uint value, bytes data);
    event LogReceive(address sender, uint value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Unathourized");
        _;
    }

    modifier onlyRecycler(uint _productId) {
        ProductLib.Product storage product = productAction.products[_productId];
        require(
            msg.sender == product.recycler,
            "Only the product owner (recycler) can perform this action"
        );
        _;
    }

    modifier onlyAuthorizedRecycler(address _recycler) {
        require(authorizedRecyclers[_recycler], "UnauthorizedRecycler");
        _;
    }

    /**
     * @dev Constructor to initialize the contract with an escrow contract address.
     * @param _escrowContract Address of the escrow contract.
     */
    constructor(address _escrowContract) {
        if (_escrowContract == address(0)) revert ErrorLib.ZeroAddress();
        owner = msg.sender;
        escrowContract = IEscrow(_escrowContract);
    }

    /**
     * @notice Onboards a recycler to the marketplace.
     * @dev Only callable by the owner.
     * @param _recycler Address of the recycler to onboard.
     */
    function onboardRecycler(address _recycler) external onlyOwner {
        if (_recycler == address(0)) revert ErrorLib.ZeroAddress();
        authorizedRecyclers[_recycler] = true;
    }

    /**
     * @notice Adds a new category to the marketplace.
     * @dev Only callable by the owner.
     * @param _name Name of the category to add.
     */
    function addCategory(string memory _name) external onlyOwner {
        categoryAction.createCategory(_name);
    }

    /**
     * @notice Retrieves all categories in the marketplace.
     * @return An array of all categories.
     */
    function getCategories()
        external
        view
        returns (CategoryLib.Category[] memory)
    {
        return categoryAction.getCategories();
    }

    /**
     * @notice Retrieves a single category by its ID.
     * @param _id ID of the category to retrieve.
     * @return Tuple containing the ID and name of the category.
     */
    function getCategory(
        uint256 _id
    ) external view returns (uint256, string memory) {
        return categoryAction.getCategory(_id);
    }

    /**
     * @notice Updates an existing category.
     * @dev Only callable by the owner.
     * @param _categoryId ID of the category to update.
     * @param _name New name of the category.
     */
    function updateCategory(
        uint _categoryId,
        string memory _name
    ) external onlyOwner {
        categoryAction.updateCategory(_categoryId, _name);
    }

    /**
     * @notice Lists a new product under a specified category.
     * @dev Only callable by an authorized recycler.
     * @param _categoryId ID of the category the product belongs to.
     * @param _price Price of the product in wei.
     * @param _quantity Quantity of the product available for sale.
     * @param _ipfsHash IPFS hash containing product metadata (name, description, image, etc.).
     */
    function listProduct(
        uint _categoryId,
        uint _price,
        uint _quantity,
        string memory _ipfsHash //Contains IPFS Hash of Name/description/image etc
    ) public onlyAuthorizedRecycler(msg.sender) {
        CategoryLib.Category storage category = categoryAction.categories[
            _categoryId
        ];
        if (category.id != _categoryId) revert ErrorLib.CategoryNotFound();

        productAction.addProduct(_categoryId, _price, _quantity, _ipfsHash);
    }

    /**
     * @notice Updates an existing product's details.
     * @dev Only callable by the product's designated recycler.
     * @param _productId ID of the product to update.
     * @param _price New price of the product in wei.
     * @param _quantity New quantity of the product.
     * @param _ipfsHash Updated IPFS hash containing product metadata.
     */
    function updateProduct(
        uint _productId,
        uint _price,
        uint _quantity,
        string memory _ipfsHash
    ) public onlyRecycler(_productId) {
        productAction.updateProduct(_productId, _price, _quantity, _ipfsHash);
    }

    /**
     * @notice Retrieves details of a single product.
     * @param _productId ID of the product to retrieve.
     * @return Product details as a Product struct.
     */
    function getProduct(
        uint _productId
    ) external view returns (ProductLib.Product memory) {
        return productAction.getProduct(_productId);
    }

    /**
     * @notice Retrieves the total count of products in the marketplace.
     * @return Total number of products.
     */
    function getProductCount() external view returns (uint) {
        return productAction.getProductCount();
    }

    /**
     * @notice Retrieves all products listed by a specific recycler.
     * @param _recycler Address of the recycler.
     * @return Array of product IDs listed by the recycler.
     */
    function getAllrecyclerProducts(
        address _recycler
    ) external view returns (uint[] memory) {
        return productAction.getAllrecyclerProducts(_recycler);
    }

    /**
     * @notice Allows a user to purchase a specified quantity of a product.
     * @param _productId ID of the product to purchase.
     * @param _quantity Quantity of the product to purchase.
     * @dev Requires the user to send an exact payment amount in ether.
     */
    function purchaseProduct(uint _productId, uint _quantity) external payable {
        ProductLib.Product storage product = productAction.products[_productId];
        if (!product.isActive) revert ErrorLib.ProductNotAvailable();
        if (product.quantity == 0) revert ErrorLib.ProductOutOfStock();

        uint totalAmount = product.price * _quantity;

        if (msg.value < totalAmount) revert ErrorLib.InsufficientEther();
        if (msg.value > totalAmount) revert ErrorLib.PayingExcess();

        product.quantity -= _quantity;

        orderAction.placeOrder(
            _productId,
            _quantity,
            totalAmount,
            escrowContract,
            product.recycler,
            msg.sender
        );
    }

    /**
     * @notice Cancels an order if it is in the processing state.
     * @param _orderId ID of the order to cancel.
     */
    function cancelOrder(uint _orderId) external {
        OrderLib.Order storage order = orderAction.orders[_orderId];
        if (order.orderId == 0) revert ErrorLib.OrderDoesNotExist();

        if (order.status != OrderLib.OrderStatus.PROCESSING)
            revert ErrorLib.CannotCancelOrder();
        ProductLib.Product storage product = productAction.products[
            order.productId
        ];
        product.quantity += order.quantity;

        orderAction.cancelOrder(_orderId, escrowContract, msg.sender);
    }

    /**
     * @notice Confirms the delivery of an order by the buyer.
     * @param _orderId ID of the order to confirm.
     */
    function confirmDelivery(uint _orderId) external {
        orderAction.confirm(_orderId, escrowContract, msg.sender);
    }

    /**
     * @notice Retrieves details of a specific order.
     * @param _orderId ID of the order to retrieve.
     * @return Order details as an Order struct.
     */
    function getOrder(
        uint _orderId
    ) external view returns (OrderLib.Order memory) {
        return orderAction.getOrder(_orderId);
    }

    /**
     * @notice Returns the total number of orders in the marketplace.
     * @return Total number of orders.
     */
    function totalOrder() external view returns (uint) {
        return orderAction.orderCount;
    }

    /**
     * @notice Fallback function to log unexpected calls.
     */
    fallback() external payable {
        emit LogFallback(msg.sender, msg.value, msg.data);
    }

    /**
     * @notice Receive function to log ether sent directly to the contract.
     */
    receive() external payable {
        emit LogReceive(msg.sender, msg.value);
    }
}
