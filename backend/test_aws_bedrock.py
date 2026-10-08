"""Unit tests for Amazon Bedrock Clinical Orchestrator."""
import unittest
from gozvision_agent.aws_bedrock import BedrockClinicalOrchestrator


class TestBedrockOrchestrator(unittest.TestCase):
    def test_invoke_clinical_reasoning_offline(self):
        orchestrator = BedrockClinicalOrchestrator()
        result = orchestrator.invoke_clinical_reasoning("Evaluate patient bilateral eye strain symptoms.")
        self.assertIn(result["status"], ["success", "simulated"])
        self.assertIn("response", result)
        self.assertIn("model_id", result)


if __name__ == "__main__":
    unittest.main()
