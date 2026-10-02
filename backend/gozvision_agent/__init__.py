"""GozVision ADK agent — grounding for the Goz copilot.

The agent module name (`gozvision_agent`) is the ADK app name the Flutter
bridge addresses via `/apps/{app}/...` and `/run`.
"""
from .agent import root_agent

__all__ = ["root_agent"]
