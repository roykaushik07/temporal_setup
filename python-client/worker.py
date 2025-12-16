"""
Temporal worker that executes workflows and activities.

The worker connects to Temporal server and polls for tasks.
It executes workflow and activity code when tasks are available.
"""

import asyncio
import logging
from temporalio.client import Client
from temporalio.worker import Worker

# Import workflow and activities
from workflows.order_workflow import OrderWorkflow
from activities.order_activities import (
    validate_order,
    process_payment,
    send_confirmation,
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def main():
    """Start the Temporal worker."""

    # Connect to Temporal server
    logger.info("Connecting to Temporal server at localhost:7233...")
    client = await Client.connect("localhost:7233")

    logger.info("Connected! Starting worker...")

    # Create and run worker
    worker = Worker(
        client,
        task_queue="order-processing-queue",
        workflows=[OrderWorkflow],
        activities=[validate_order, process_payment, send_confirmation],
    )

    logger.info("Worker started. Polling for tasks on 'order-processing-queue'...")
    logger.info("Press Ctrl+C to stop")

    # Run worker until interrupted
    await worker.run()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Worker stopped")
