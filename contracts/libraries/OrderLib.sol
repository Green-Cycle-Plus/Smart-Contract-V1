// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ErrorLib.sol";
import "./CategoryLib.sol";
import "../interfaces/IEscrow.sol";

/**
 * @title OrderLib
 * @dev Library for managing orders in the marketplace with escrow functionality.
 */
library OrderLib {
    using CategoryLib for CategoryLib.CategoryStorage;

    enum OrderStatus {
        PROCESSING,
        IN_TRANSIT,
        DELIVERED,
        CANCELLED
    }

    struct Order {
        uint orderId;
        uint256 escrowId;
        uint productId;
        address buyer;
        address recycler;
        uint quantity;
        uint totalAmount;
        OrderStatus status;
    }

    struct OrderStorage {
        mapping(uint => Order) orders;
        uint orderCount;
    }

    event OrderCreated(uint orderid, address buyer, uint totalAmount);
    event OrderDelivered(uint indexed orderId);
    event OrderCancelled(
        uint indexed orderId,
        address indexed _cancelledBy,
        string userType
    );
    event ProductPurchased(
        uint indexed productId,
        address indexed buyer,
        uint orderId
    );

    /**
     * @notice Places an order for a specified product.
     * @dev Creates an escrow for the order and stores order details.
     *      Refunds any excess payment to the buyer.
     * @param self Reference to OrderStorage.
     * @param _productId ID of the product being ordered.
     * @param _quantity Quantity of the product being ordered.
     * @param totalAmount Total amount payable for the order.
     * @param escrowContract Reference to the escrow contract for managing payments.
     * @param recycler Address of the recycler (product owner).
     * @param buyer Address of the buyer placing the order.
     */
    function placeOrder(
        OrderStorage storage self,
        uint _productId,
        uint _quantity,
        uint totalAmount,
        IEscrow escrowContract,
        address recycler,
        address buyer
    ) internal {
        // Create a single escrow for this order
        escrowContract.createEscrow{value: totalAmount}(recycler);
        uint256 escrowId = escrowContract.escrowCounter();

        self.orderCount++;
        self.orders[self.orderCount] = Order({
            orderId: self.orderCount,
            escrowId: escrowId,
            productId: _productId,
            buyer: buyer,
            recycler: recycler,
            quantity: _quantity,
            totalAmount: totalAmount,
            status: OrderStatus.PROCESSING
        });

        if (msg.value > totalAmount) {
            //Refund From Escrow
            payable(buyer).transfer(msg.value - totalAmount);
        }
        emit ProductPurchased(_productId, buyer, self.orderCount);
    }

    /**
     * @notice Confirms the delivery of an order by the buyer.
     * @dev Updates the order status to DELIVERED and releases funds from escrow.
     * @param self Reference to OrderStorage.
     * @param _orderId ID of the order to confirm.
     * @param escrowContract Reference to the escrow contract.
     * @param sender Address of the caller (must be the buyer).
     */
    function confirm(
        OrderStorage storage self,
        uint _orderId,
        IEscrow escrowContract,
        address sender
    ) internal {
        Order storage order = self.orders[_orderId];
        if (order.buyer == address(0)) revert ErrorLib.OrderDoesNotExist();
        if (order.buyer != sender) revert ErrorLib.OnlyBuyer();
        if (order.status == OrderStatus.DELIVERED)
            revert ErrorLib.AlreadyDelivered();

        order.status = OrderStatus.DELIVERED;
        escrowContract.releaseEscrow(order.escrowId);
        emit OrderDelivered(_orderId);
    }

    /**
     * @notice Cancels an order by either the buyer or recycler.
     * @dev Updates order status to CANCELLED and refunds escrow to the buyer.
     * @param self Reference to OrderStorage.
     * @param _orderId ID of the order to cancel.
     * @param escrowContract Reference to the escrow contract.
     * @param sender Address of the caller (must be buyer or recycler).
     */
    function cancelOrder(
        OrderStorage storage self,
        uint _orderId,
        IEscrow escrowContract,
        address sender
    ) internal {
        Order storage order = self.orders[_orderId];
        if (order.orderId == 0) revert ErrorLib.OrderDoesNotExist();

        if (order.status != OrderStatus.PROCESSING)
            revert ErrorLib.CannotCancelOrder();

        if (sender == order.buyer) {
            order.status = OrderStatus.CANCELLED;
            escrowContract.refundEscrow(order.escrowId);
            emit OrderCancelled(
                _orderId,
                msg.sender,
                "Buyer cancelled the order"
            );
        } else if (sender == order.recycler) {
            order.status = OrderStatus.CANCELLED;
            escrowContract.refundEscrow(order.escrowId);

            emit OrderCancelled(
                _orderId,
                msg.sender,
                "Recycler cancelled the order"
            );
        } else {
            revert("Only the buyer or recycler can cancel the order");
        }
    }

    /**
     * @notice Retrieves order details by order ID.
     * @param self Reference to OrderStorage.
     * @param _orderId ID of the order to retrieve.
     * @return The Order struct containing order details.
     */
    function getOrder(
        OrderStorage storage self,
        uint _orderId
    ) internal view returns (Order memory) {
        Order storage order = self.orders[_orderId];
        if (order.orderId == 0) revert ErrorLib.OrderDoesNotExist();
        return self.orders[_orderId];
    }

    /**
     * @notice Retrieves the total number of orders.
     * @param self Reference to OrderStorage.
     * @return orderCount Total count of orders.
     */
    function totalOrder(
        OrderStorage storage self
    ) internal view returns (uint orderCount) {
        return self.orderCount;
    }
}
