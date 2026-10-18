"""Unit tests for Amazon Bedrock Clinical Orchestrator."""
import unittest
from gozvision_agent.aws_bedrock import BedrockClinicalOrchestrator


class TestBedrockOrchestrator(unittest.TestCase):
    def test_invoke_clinical_reasoning_offline(self):
        orchestrator = BedrockClinicalOrchestrator()
        result = orchestrator.invoke_clinical_reasoning("Evaluate patient bilateral eye strain symptoms.")
        self.assertIn(result["status"], ["success", "simulated"])
        self.assertIn("response", result)
    def test_converse_clinical_reasoning(self):
        orchestrator = BedrockClinicalOrchestrator()
        result = orchestrator.converse_clinical_reasoning(
            messages=[{"role": "user", "content": "Triage dry AMD progression with visual drop."}],
            thinking_budget_tokens=1024,
        )
        self.assertIn(result["status"], ["success", "simulated"])
        self.assertIn("output_text", result)
        self.assertIsNotNone(result["thinking_content"])


if __name__ == "__main__":
    unittest.main()

