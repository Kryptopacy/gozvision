import unittest
from gozvision_agent.commerce import BachsCommerceClient


class TestBachsCommerce(unittest.TestCase):
    def test_bachs_client_initialization(self):
        client = BachsCommerceClient(api_key="sk_sandbox_test_123")
        self.assertEqual(client.base_url, "https://sandbox-api.bachs.io/v1")
        self.assertEqual(client.api_key, "sk_sandbox_test_123")
        self.assertFalse(client.live_mode)

    def test_create_checkout_session(self):
        client = BachsCommerceClient()
        session = client.create_checkout_session(
            product_id="prod_01",
            product_name="Goz Titanium Vista Frame",
            price=185.00,
            currency="USD",
            customer_email="patient@example.com",
            customer_name="Eleanor Vance",
            clinic_id="clinic_001",
        )
        self.assertIn("checkout_url", session)
        self.assertEqual(session["status"], "open")
        self.assertEqual(session["amount"], "185.00")
        self.assertEqual(session["currency"], "USD")

    def test_get_balances(self):
        client = BachsCommerceClient()
        balances = client.get_balances()
        self.assertIn("balances", balances)
        curr_codes = [b["currency"] for b in balances["balances"]]
        self.assertIn("USD", curr_codes)
        self.assertIn("NGN", curr_codes)

    def test_register_payout_destination(self):
        client = BachsCommerceClient()
        dest = client.register_payout_destination(
            account_number="0123456789",
            bank_code="058",
            currency="NGN",
            account_name="GOZVISION CLINIC",
        )
        self.assertTrue(dest["id"].startswith("pd_"))
        self.assertEqual(dest["currency"], "NGN")
        self.assertTrue(dest["is_usable"])
        self.assertEqual(dest["account_number"], "0123456789")

    def test_execute_payout(self):
        client = BachsCommerceClient()
        payout = client.execute_payout(
            destination_id="pd_7Kq2mNv4XbR9dLc0",
            amount=50000.00,
            currency="NGN",
            reference="PO-TEST-001",
        )
        self.assertTrue(payout["id"].startswith("pay_"))
        self.assertEqual(payout["amount"], "50000.00")
        self.assertEqual(payout["currency"], "NGN")
        self.assertEqual(payout["status"], "completed")
        self.assertGreater(float(payout["total_debited"]), 50000.00)

    def test_webhook_processing(self):
        client = BachsCommerceClient()

        # 1. Collection Succeeded
        event_payload = {
            "id": "evt_001",
            "type": "collection.succeeded",
            "data": {
                "checkout_id": "chk_2N3o4P5q6R7s8T9u",
                "amount": "185.00",
                "currency": "USD",
                "status": "SUCCEEDED",
            },
        }
        res = client.process_webhook_event(event_payload)
        self.assertTrue(res["handled"])
        self.assertEqual(res["action"], "order_fulfilled")
        self.assertEqual(res["status"], "PAID")

        # 2. Payout Paid
        payout_paid_event = {
            "id": "evt_002",
            "type": "payout.paid",
            "data": {"id": "pay_9A0b1C2d3E4f"},
        }
        payout_res = client.process_webhook_event(payout_paid_event)
        self.assertTrue(payout_res["handled"])
        self.assertEqual(payout_res["action"], "payout_settled")
        self.assertEqual(payout_res["status"], "COMPLETED")


if __name__ == "__main__":
    unittest.main()
