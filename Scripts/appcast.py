#!/usr/bin/env python3
"""Generate and validate EdgeControl feeds before publishing any release."""
import argparse
import base64
import datetime
import email.utils
from pathlib import Path
import xml.etree.ElementTree as ET

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
LEGACY = "http://www.andymatusiak.com/sparkle"
NS = "{" + SPARKLE + "}"
ET.register_namespace("sparkle", SPARKLE)


def normalize(root):
    """Repair the one known historical URI without changing signed archives."""
    old = "{" + LEGACY + "}"
    for element in root.iter():
        if element.tag.startswith(old):
            element.tag = NS + element.tag[len(old):]
        for key, value in list(element.attrib.items()):
            if key.startswith(old):
                replacement = NS + key[len(old):]
                if replacement in element.attrib and element.attrib[replacement] != value:
                    raise ValueError("Conflicting legacy and canonical Sparkle attributes")
                del element.attrib[key]
                element.set(replacement, value)
    return root


def validate(root, latest_build):
    if root.tag != "rss" or root.get("version") != "2.0":
        raise ValueError("Expected RSS 2.0")
    channels = root.findall("channel")
    if len(channels) != 1:
        raise ValueError("Expected one update channel")
    items = channels[0].findall("item")
    if not items:
        raise ValueError("Empty update feed")
    builds = []
    for item in items:
        enclosures = item.findall("enclosure")
        if len(enclosures) != 1:
            raise ValueError("Each release requires one archive")
        enclosure = enclosures[0]
        build = enclosure.get(NS + "version") or item.findtext(NS + "version")
        version = enclosure.get(NS + "shortVersionString") or item.findtext(NS + "shortVersionString")
        if not build or not build.isdigit() or int(build) <= 0 or not version:
            raise ValueError("Missing canonical Sparkle version; check namespace URI")
        url = enclosure.get("url", "")
        expected = f"https://github.com/leecdiang/EdgeControl/releases/download/v{version}/EdgeControl-{version}-macOS.zip"
        if url != expected or int(enclosure.get("length", "0")) <= 0:
            raise ValueError("Archive URL/version/length mismatch")
        signature = base64.b64decode(enclosure.get(NS + "edSignature", ""), validate=True)
        if len(signature) != 64:
            raise ValueError("Expected a 64-byte Ed25519 signature")
        builds.append(int(build))
    if builds[0] != int(latest_build) or builds != sorted(set(builds), reverse=True):
        raise ValueError("Feed builds must be unique and newest first")
    return items


def signature_for(root, version, build):
    """Read either Sparkle-supported version location for the local installer."""
    matches = []
    for item in root.findall("channel/item"):
        enclosure = item.find("enclosure")
        if enclosure is None:
            continue
        item_build = enclosure.get(NS + "version") or item.findtext(NS + "version")
        item_version = enclosure.get(NS + "shortVersionString") or item.findtext(NS + "shortVersionString")
        if item_build == str(build) and item_version == version:
            matches.append(enclosure.get(NS + "edSignature", ""))
    if len(matches) != 1 or len(base64.b64decode(matches[0], validate=True)) != 64:
        raise ValueError("Expected one signed archive matching the requested version and build")
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--build", required=True, type=int)
    parser.add_argument("--version")
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--signature")
    parser.add_argument("--description")
    args = parser.parse_args()
    root = normalize(ET.parse(args.source).getroot())
    if args.version:
        if not (args.archive and args.signature and args.description):
            parser.error("New releases require archive, signature and description")
        channel = root.find("channel")
        if channel is None:
            raise ValueError("Missing update channel")
        item = ET.Element("item")
        ET.SubElement(item, "title").text = "EdgeControl " + args.version
        ET.SubElement(item, "pubDate").text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
        ET.SubElement(item, NS + "version").text = str(args.build)
        ET.SubElement(item, NS + "shortVersionString").text = args.version
        ET.SubElement(item, NS + "minimumSystemVersion").text = "13.0"
        ET.SubElement(item, "description").text = args.description
        ET.SubElement(item, "enclosure", {
            "url": f"https://github.com/leecdiang/EdgeControl/releases/download/v{args.version}/EdgeControl-{args.version}-macOS.zip",
            "length": str(args.archive.stat().st_size), "type": "application/octet-stream",
            NS + "edSignature": args.signature,
        })
        channel.insert(0, item)
    validate(root, args.build)
    ET.indent(root, space="    ")
    ET.ElementTree(root).write(args.output, encoding="utf-8", xml_declaration=True)
    print(f"Validated {len(root.findall('channel/item'))} releases; newest build {args.build}")


if __name__ == "__main__":
    main()
