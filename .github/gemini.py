from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# Gemini 3.1 Flash Lite
DEFAULT_MODEL = "gemini-3.1-flash-lite"
DEFAULT_MIN_INTERVAL = 172.8
DIRECTIVE_PATTERN = re.compile(
	r"(?m)^\s*(?://|#|--|/\*+|\*+)?\s*@foez-bhai\b(?P<instruction>.*)$"
)


def find_first_directive(text: str) -> re.Match[str] | None:
	return DIRECTIVE_PATTERN.search(text)


def strip_code_fences(text: str) -> str:
	stripped = text.strip()
	if not stripped.startswith("```"):
		return text

	lines = stripped.splitlines()
	if len(lines) < 3:
		return text

	if lines[0].startswith("```") and lines[-1].strip() == "```":
		return "\n".join(lines[1:-1]).strip("\n") + "\n"

	return text


def build_prompt(file_name: str, file_text: str, instruction: str) -> str:
	return (
		"You are editing a source file. "
		"Apply only the first @foez-bhai directive described below and return only the full updated file contents. "
		"Do not add explanations. Remove the processed @foez-bhai line from the file. "
		"Leave any other @foez-bhai directives unchanged unless the requested edit must touch nearby code.\n\n"
		f"File name: {file_name}\n"
		f"Instruction from the first @foez-bhai marker: {instruction.strip()}\n\n"
		"Current file contents:\n"
		"```text\n"
		f"{file_text}"
		"\n```\n"
	)


def call_gemini(api_key: str, model: str, prompt: str) -> str:
	url = (
		"https://generativelanguage.googleapis.com/v1beta/models/"
		f"{urllib.parse.quote(model, safe='')}:generateContent?key={urllib.parse.quote(api_key, safe='')}"
	)
	payload = {
		"contents": [
			{
				"parts": [
					{
						"text": prompt,
					}
				]
			}
		],
		"generationConfig": {
			"temperature": 0.2,
		},
	}
	request = urllib.request.Request(
		url,
		data=json.dumps(payload).encode("utf-8"),
		headers={"Content-Type": "application/json"},
		method="POST",
	)

	try:
		with urllib.request.urlopen(request, timeout=120) as response:
			body = response.read().decode("utf-8")
	except urllib.error.HTTPError as exc:
		details = exc.read().decode("utf-8", errors="replace")
		raise RuntimeError(f"Gemini API request failed: HTTP {exc.code}: {details}") from exc
	except urllib.error.URLError as exc:
		raise RuntimeError(f"Gemini API request failed: {exc.reason}") from exc

	data = json.loads(body)
	candidates = data.get("candidates") or []
	if not candidates:
		raise RuntimeError(f"Gemini API returned no candidates: {body}")

	parts = candidates[0].get("content", {}).get("parts", [])
	text = "".join(part.get("text", "") for part in parts)
	text = strip_code_fences(text)
	if not text.strip():
		raise RuntimeError(f"Gemini API returned empty text: {body}")
	return text


def ensure_processed_directive_removed(updated_text: str, instruction: str) -> str:
	updated_match = find_first_directive(updated_text)
	if updated_match and updated_match.group("instruction").strip() == instruction.strip():
		start, end = updated_match.span()
		line_end = end
		if line_end < len(updated_text) and updated_text[line_end:line_end + 1] == "\n":
			line_end += 1
		return updated_text[:start] + updated_text[line_end:]
	return updated_text


def process_file(
	input_path: Path,
	api_key: str,
	model: str,
	min_interval: float,
	output_path: Path | None = None,
) -> tuple[Path, int]:
	current_text = input_path.read_text(encoding="utf-8")
	if output_path is None:
		output_path = input_path.with_name(f"gemini.{input_path.name}")
	requests_made = 0
	last_request_started = 0.0

	while True:
		match = find_first_directive(current_text)
		if not match:
			break

		instruction = match.group("instruction").strip()
		if not instruction:
			raise RuntimeError("Found an @foez-bhai marker without any instruction text on the same line.")

		if requests_made:
			elapsed = time.monotonic() - last_request_started
			if elapsed < min_interval:
				time.sleep(min_interval - elapsed)

		prompt = build_prompt(input_path.name, current_text, instruction)
		last_request_started = time.monotonic()
		current_text = call_gemini(api_key, model, prompt)
		current_text = ensure_processed_directive_removed(current_text, instruction)
		requests_made += 1

	if not requests_made:
		raise RuntimeError("No @foez-bhai directives were found in the input file.")

	output_path.write_text(current_text, encoding="utf-8")
	return output_path, requests_made


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description="Apply @foez-bhai directives in a text file and write the result to gemini.<original-name>."
	)
	parser.add_argument("input_file", help="Path to the input file that contains @foez-bhai directives.")
	parser.add_argument(
		"-o",
		"--output",
		help="Path to the output file. Defaults to gemini.<original-name> in the input file directory.",
	)
	parser.add_argument("--api-key", required=True, help="Gemini API key.")
	parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Gemini model to use. Default: {DEFAULT_MODEL}")
	parser.add_argument(
		"--min-interval",
		type=float,
		default=DEFAULT_MIN_INTERVAL,
		help=f"Minimum seconds between Gemini API requests. Default: {DEFAULT_MIN_INTERVAL}",
	)
	return parser.parse_args()


def main() -> int:
	args = parse_args()
	input_path = Path(args.input_file).expanduser().resolve()
	if not input_path.is_file():
		print(f"Input file does not exist: {input_path}", file=sys.stderr)
		return 1

	api_key = args.api_key.strip()
	if not api_key:
		print("--api-key must not be empty.", file=sys.stderr)
		return 1

	if args.min_interval < 0:
		print("--min-interval must be non-negative.", file=sys.stderr)
		return 1

	output_path = None
	if args.output:
		output_path = Path(args.output).expanduser().resolve()
		output_path.parent.mkdir(parents=True, exist_ok=True)

	try:
		output_path, requests_made = process_file(
			input_path,
			api_key,
			args.model,
			args.min_interval,
			output_path,
		)
	except Exception as exc:
		print(str(exc), file=sys.stderr)
		return 1

	print(f"Created {output_path} using {requests_made} Gemini request(s).")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
