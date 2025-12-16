"""
Order processing activities for Temporal workflow demo.
Each activity represents a discrete unit of work.
"""

from temporalio import activity
import time


@activity.defn
async def validate_order(order_id: str) -> str:
    """
    Validate the order details.

    Args:
        order_id: The order identifier

    Returns:
        Validation result message
    """
    activity.logger.info(f"Validating order: {order_id}")

    # Simulate validation work
    time.sleep(1)

    # In a real app, you'd check inventory, pricing, etc.
    if not order_id:
        raise ValueError("Order ID cannot be empty")

    activity.logger.info(f"Order {order_id} validated successfully")
    return f"Order {order_id} is valid"


@activity.defn
async def process_payment(order_id: str, amount: float) -> str:
    """
    Process payment for the order.

    Args:
        order_id: The order identifier
        amount: Payment amount

    Returns:
        Payment confirmation
    """
    activity.logger.info(f"Processing payment for order {order_id}: ${amount}")

    # Simulate payment processing
    time.sleep(2)

    # In a real app, you'd call a payment gateway
    transaction_id = f"TXN-{order_id}-{int(time.time())}"

    activity.logger.info(f"Payment processed: {transaction_id}")
    return f"Payment processed: {transaction_id}"


@activity.defn
async def send_confirmation(order_id: str, email: str) -> str:
    """
    Send order confirmation email.

    Args:
        order_id: The order identifier
        email: Customer email address

    Returns:
        Confirmation message
    """
    activity.logger.info(f"Sending confirmation for order {order_id} to {email}")

    # Simulate email sending
    time.sleep(1)

    # In a real app, you'd call an email service
    activity.logger.info(f"Confirmation sent to {email}")
    return f"Confirmation email sent to {email}"
