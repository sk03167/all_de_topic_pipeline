import unittest
from unittest.mock import Mock, patch

from generate_events import emit_clickstream


class GeneratorTests(unittest.TestCase):
    @patch("generate_events.uuid.uuid4", return_value="event-1")
    def test_clickstream_uses_session_as_kafka_key(self, _):
        producer = Mock()
        emit_clickstream(producer, "customer-1")
        kwargs = producer.produce.call_args.kwargs
        self.assertEqual(kwargs["topic"], "olist.clickstream.v1")
        self.assertIn("customer-1", kwargs["value"])


if __name__ == "__main__":
    unittest.main()
