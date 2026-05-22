"""Parse simulator stdout lines into structured dicts."""
import re


def parse_line(line: str) -> dict:
    """
    Expected formats:
      PASS idx=3 cycles=544 sram_rd=544 sram_wr=1056
      FAIL idx=3 expected=5 cycles=544 sram_rd=544 sram_wr=1056
      FAIL timeout
    """
    line = line.strip()
    result = {"raw": line}

    if line.startswith("PASS"):
        result["status"] = "PASS"
    elif line.startswith("FAIL"):
        result["status"] = "FAIL"
    else:
        result["status"] = "UNKNOWN"
        return result

    for key in ("idx", "expected", "cycles", "sram_rd", "sram_wr"):
        m = re.search(rf"{key}=(\d+)", line)
        if m:
            result[key] = int(m.group(1))

    return result


if __name__ == "__main__":
    import sys
    for line in sys.stdin:
        print(parse_line(line))
