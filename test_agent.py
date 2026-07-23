import os
import tempfile
import unittest
from unittest.mock import MagicMock, patch

# server.py constructs the genai.Client at import time, which requires a key
# in the environment. A dummy value is enough for these mocked tests.
os.environ.setdefault("GEMINI_API_KEY", "test-key")

from server import _get_image_data, generate_video, edit_video, animate_image, mcp


class TestOmniVideoAgent(unittest.TestCase):
    def setUp(self):
        # Create a temporary file for image-input tests
        self.test_dir = tempfile.TemporaryDirectory()
        self.test_image_path = os.path.join(self.test_dir.name, "test.png")
        # Write dummy png bytes
        with open(self.test_image_path, "wb") as f:
            f.write(
                b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
            )

    def tearDown(self):
        self.test_dir.cleanup()

    def _mock_interaction(self, interaction_id="int_123", data="ZHVtbXlfdmlkZW8="):
        interaction = MagicMock()
        interaction.id = interaction_id
        if data is None:
            interaction.output_video = None
        else:
            interaction.output_video = MagicMock()
            interaction.output_video.data = data
            interaction.output_video.uri = None
        return interaction

    def test_get_image_data_valid(self):
        """Test image encoding helper with a valid image file."""
        data = _get_image_data(self.test_image_path)
        self.assertEqual(data["type"], "image")
        self.assertEqual(data["mime_type"], "image/png")
        self.assertTrue(len(data["data"]) > 0)

    def test_get_image_data_missing(self):
        """Test image encoding helper raises FileNotFoundError if file is missing."""
        with self.assertRaises(FileNotFoundError):
            _get_image_data("non_existent_file.png")

    @patch("server.client")
    def test_generate_video_success(self, mock_client):
        """Test generate_video tool with mocked Interactions API response."""
        mock_client.interactions.create.return_value = self._mock_interaction()

        with patch("server.open", unittest.mock.mock_open()):
            result = generate_video(prompt="test prompt", aspect_ratio="16:9")
        self.assertIn("🟢 Video successfully saved!", result)
        self.assertIn("int_123", result)
        self.assertIn("Delivery mode: inline", result)
        create_kwargs = mock_client.interactions.create.call_args.kwargs
        self.assertEqual(create_kwargs["response_format"]["aspect_ratio"], "16:9")
        self.assertTrue(create_kwargs["store"])

    @patch("server.client")
    def test_generate_video_no_output_video(self, mock_client):
        """Test generate_video tool when no output video is returned by the API."""
        mock_client.interactions.create.return_value = self._mock_interaction(data=None)

        result = generate_video(prompt="test prompt")
        self.assertIn("🟢 Interaction completed successfully.", result)
        self.assertIn("No direct video output was found", result)

    @patch("server.client")
    def test_generate_video_failure(self, mock_client):
        """Test generate_video tool gracefully handles exceptions."""
        mock_client.interactions.create.side_effect = Exception("API Key expired")

        result = generate_video(prompt="test prompt")
        self.assertIn("🔴 Generation failed: API Key expired", result)

    @patch("server.client")
    def test_edit_video_success(self, mock_client):
        """Test edit_video tool chains the previous interaction ID."""
        mock_client.interactions.create.return_value = self._mock_interaction(
            interaction_id="int_456"
        )

        with patch("server.open", unittest.mock.mock_open()):
            result = edit_video(
                previous_interaction_id="int_123", edit_prompt="make it rain"
            )
        self.assertIn("🟢 Video successfully saved!", result)
        self.assertIn("int_456", result)
        create_kwargs = mock_client.interactions.create.call_args.kwargs
        self.assertEqual(create_kwargs["previous_interaction_id"], "int_123")

    @patch("server.client")
    def test_animate_image_success(self, mock_client):
        """Test animate_image sends the encoded image plus the motion prompt."""
        mock_client.interactions.create.return_value = self._mock_interaction(
            interaction_id="int_789"
        )

        # Encode the image before patching open, which _get_image_data also uses
        real_data = _get_image_data(self.test_image_path)
        with patch("server._get_image_data", return_value=real_data):
            with patch("server.open", unittest.mock.mock_open()):
                result = animate_image(
                    image_path=self.test_image_path, motion_prompt="slow pan"
                )
        self.assertIn("🟢 Video successfully saved!", result)
        self.assertIn("int_789", result)
        create_input = mock_client.interactions.create.call_args.kwargs["input"]
        self.assertEqual(create_input[0]["type"], "image")
        self.assertEqual(create_input[1], {"type": "text", "text": "slow pan"})

    @patch("server.client")
    def test_animate_image_missing_file(self, mock_client):
        """Test animate_image returns an error string for a missing image."""
        result = animate_image(image_path="missing.png", motion_prompt="pan")
        self.assertIn("🔴 Animation failed:", result)
        mock_client.interactions.create.assert_not_called()

    def test_mcp_tools_registered(self):
        """Verify that the expected tools are registered to the FastMCP server."""
        tools = [t.name for t in mcp._tool_manager.list_tools()]
        for tool in [
            "generate_video",
            "edit_video",
            "animate_image",
            "interpolate_images",
            "generate_with_subjects",
            "edit_user_video",
            "upload_to_youtube",
            "get_help",
        ]:
            self.assertIn(tool, tools)

    def test_get_help(self):
        """Verify that get_help documents every exposed tool and delivery modes."""
        from server import get_help

        result = get_help()
        for tool in [
            "generate_video",
            "edit_video",
            "animate_image",
            "interpolate_images",
            "generate_with_subjects",
            "edit_user_video",
            "upload_to_youtube",
            "get_help",
        ]:
            self.assertIn(tool, result)
        self.assertIn("Delivery Modes", result)


if __name__ == "__main__":
    unittest.main()
