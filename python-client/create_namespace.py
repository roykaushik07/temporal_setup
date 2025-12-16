"""
Create the 'default' namespace in Temporal
"""
import asyncio
from temporalio.client import Client


async def main():
    # Connect to Temporal server
    client = await Client.connect("localhost:7233")

    try:
        # Try to create the default namespace
        await client.operator_service.register_namespace(
            namespace="default",
            description="Default namespace for workflows",
            owner_email="admin@company.com",
            retention_period_days=7
        )
        print("✅ Namespace 'default' created successfully!")
    except Exception as e:
        if "already exists" in str(e).lower():
            print("✅ Namespace 'default' already exists")
        else:
            print(f"❌ Error creating namespace: {e}")
            raise

    # List namespaces to confirm
    print("\n📋 Available namespaces:")
    response = await client.operator_service.list_namespaces()
    for namespace in response.namespaces:
        print(f"  - {namespace.namespace_info.name}")


if __name__ == "__main__":
    asyncio.run(main())
