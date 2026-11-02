import copy
import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from appcast import LEGACY, NS, normalize, validate

FIXTURE = Path(__file__).parent / "Fixtures/appcast-legacy-namespace.xml"


class AppcastTests(unittest.TestCase):
    def setUp(self):
        self.original = ET.parse(FIXTURE).getroot()
        self.fixed = normalize(copy.deepcopy(self.original))

    def test_well_formed_legacy_xml_is_not_a_valid_update_feed(self):
        with self.assertRaisesRegex(ValueError, "namespace"):
            validate(self.original, 17)

    def test_normalizing_preserves_all_release_values_and_signatures(self):
        def records(root):
            return [(e.tag.split("}")[-1], (e.text or "").strip(),
                     sorted((k.split("}")[-1], v) for k, v in e.attrib.items()))
                    for e in root.iter()]
        self.assertEqual(records(self.original), records(self.fixed))
        self.assertEqual(len(validate(self.fixed, 17)), 10)
        self.assertNotIn(LEGACY, ET.tostring(self.fixed).decode())

    def test_normalizing_is_idempotent(self):
        before = ET.tostring(self.fixed)
        self.assertEqual(before, ET.tostring(normalize(self.fixed)))

    def test_rejects_duplicate_or_misordered_builds(self):
        channel = self.fixed.find("channel")
        channel.insert(0, copy.deepcopy(channel.find("item")))
        with self.assertRaisesRegex(ValueError, "unique"):
            validate(self.fixed, 17)

    def test_rejects_invalid_signature_and_archive_binding(self):
        for key, value in [(NS + "edSignature", "AAAA"), ("length", "0"),
                           ("url", "https://example.org/replaced.zip")]:
            root = copy.deepcopy(self.fixed)
            root.find("channel/item/enclosure").set(key, value)
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(root, 17)

    def test_rejects_conflicting_namespace_attributes(self):
        enclosure = self.fixed.find("channel/item/enclosure")
        enclosure.set("{" + LEGACY + "}version", "999")
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            normalize(self.fixed)


if __name__ == "__main__":
    unittest.main()
